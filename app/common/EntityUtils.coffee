@EntityUtils = {}
evalEngine = null

Meteor.startup ->
  evalEngine = new EvaluationEngine(schema: Entities.simpleSchema())

_.extend EntityUtils,

  evaluate: (entity, paramIds) ->
    paramIds = if Types.isArray(paramIds) then paramIds else [paramIds]
    typologyClass = Entities.getTypologyClass(entity)
    evalEngine.evaluate(model: entity, paramIds: paramIds, typologyClass: typologyClass)

if Meteor.isClient

  _renderQueue = null
  resetRenderQueue = -> _renderQueue = new DeferredQueueMap()
  Meteor.startup -> resetRenderQueue()

  _.extend EntityUtils,

    toGeoEntityArgs: (id) ->
      AtlasConverter.getInstance().then (converter) ->
        entity = Entities.getFlattened(id)
        typology = Typologies.findOne(entity.typology)
        typologyClass = Entities.getTypologyClass(id)
        space = entity.parameters.space
        typologySpace = typology.parameters.space
        args =
          id: id
          vertices: space?.geom_2d ? typologySpace?.geom_2d
          height: space?.height ? 5
          zIndex: 1
          displayMode: displayMode
          style:
            fillColor: '#ccc'
            borderColor: '#666'
        if typologyClass == 'PATHWAY'
          widthParamId = 'space.width'
          evalEngine.evaluate(model: entity, paramIds: [widthParamId], typologyClass: typologyClass)
          args.width = SchemaUtils.getParameterValue(entity, widthParamId)
          args.style.fillColor = '#000'
          displayMode = 'line'
        else
          displayMode = Session.get('entityDisplayMode')
        converter.toGeoEntityArgs(args)

    _getMesh: (id) ->
      entity = Entities.getFlattened(id)
      meshFileId = SchemaUtils.getParameterValue(entity, 'space.geom_3d')
      if meshFileId
        Files.downloadJson(meshFileId)
      else
        meshDf = Q.defer()
        meshDf.resolve(null)
        meshDf.promise

    _buildMeshCollection: (id, centroid) ->
      df = Q.defer()
      geoEntity = AtlasManager.getEntity(id)
      require ['atlas/model/GeoPoint'], (GeoPoint) =>
        @_getMesh(id).then (result) ->
          unless result
            df.resolve(null)
            return
          # Modify the ID of c3ml entities to allow reusing them for multiple collections.
          c3mls = _.map result.c3mls, (c3ml) ->
            c3ml.id = id + ':' + c3ml.id
            c3ml.show = true
            c3ml
          # Ignore all collections in the c3ml, since they don't affect visualisation.
          c3mls = _.filter c3mls, (c3ml) -> c3ml.type != 'collection'
          try
            c3mlEntities = AtlasManager.renderEntities(c3mls)
          catch e
            console.error('Error when rendering mesh entities', e)
          ids = []
          _.each c3mlEntities, (c3mlEntity) ->
            mesh = null
            if c3mlEntity.getForm
              mesh = c3mlEntity.getForm()
              ids.push(c3mlEntity.getId()) if mesh
          # Add c3mls to a single collection and use it as the mesh display mode for the
          # feature.
          require ['atlas/model/Collection'], (Collection) ->
            # TODO(aramk) Use dependency injection to prevent the need for passing manually.
            deps = geoEntity._bindDependencies({show: true})
            collection = new Collection('collection-' + id, {entities: ids}, deps)
            df.resolve(collection)
      df.promise

    render: (id) -> _renderQueue.add(id, => @_render(id))

    _render: (id) ->
      df = Q.defer()
      geoEntity = AtlasManager.getEntity(id)
      if geoEntity
        AtlasManager.showEntity(id)
        df.resolve(geoEntity)
      else
        @toGeoEntityArgs(id).then(
          (entityArgs) =>
            entity = Entities.getFlattened(id)
            typologyClass = Entities.getTypologyClass(id)

            doRender = (id, geoEntity) =>
              AtlasManager.showEntity(id)
              @_setUpPopup(geoEntity)
              df.resolve(geoEntity)

            if typologyClass == 'PATHWAY'
              geoEntity = AtlasManager.renderEntity(entityArgs)
              doRender(id, geoEntity)
              return

            azimuth = SchemaUtils.getParameterValue(entity, 'orientation.azimuth')
            # If the geoEntity was rendered using the Typology geometry, centre it based on the Lot.
            lot = Lots.findOne(entity.lot)
            unless lot
              EntityUtils.unrender(id)
              throw new Error('Rendered geoEntity does not have an accompanying lot.')
            lotId = lot._id
            require [
              'atlas/model/Feature',
              'atlas/model/Vertex'
            ], (Feature, Vertex) =>
              LotUtils.render(lotId).then (lotEntity) =>
                lotCentroid = lotEntity.getCentroid()
                # Hide the entity initially to avoid showing the transition.
                entityArgs.show = false
                delete entityArgs.displayMode
                # Render the Entity once the Lot has been rendered.
                geoEntity = AtlasManager.renderEntity(entityArgs)
                @._buildMeshCollection(id, lotCentroid).then (collection) ->
                  if collection
                    meshEntity = collection
                    geoEntity.setForm(Feature.DisplayMode.MESH, meshEntity)
                  # Ensure all forms have the same centroid.
                  _.each Feature.DisplayMode, (displayMode) ->
                    form = geoEntity.getForm(displayMode)
                    if form
                      form.setCentroid(lotCentroid)
                      # Apply rotation based on the azimuth.
                      form.setRotation(new Vertex(0, 0, azimuth)) if azimuth?
                  geoEntity.setDisplayMode(Session.get('entityDisplayMode'))
                  doRender(id, geoEntity)
        ).catch(df.reject)
      df.promise

    _setUpPopup: (geoEntity) ->
      entity = Entities.getFlattened(geoEntity.getId())
      typology = Typologies.findOne(entity.typology)
      typologyClassId = SchemaUtils.getParameterValue(entity, 'general.class')
      typologyClass = Typologies.classes[typologyClassId]
      subclass = SchemaUtils.getParameterValue(entity, 'general.subclass')
      AtlasManager.getAtlas().then (atlas) ->
        atlas.publish('popup/onSelection', {
          entity: geoEntity
          content: ->
            '<div class="typology-name">' + typology.name + '</div>'
          title: ->
            title = ''
            _.each ['name'], (attr) ->
              value = (entity[attr] ? '').trim()
              if value
                title += '<div class="' + attr + '">' + value + '</div>'
            title
          onCreate: (popup) ->
            $popup = $(popup.getDom())
            $('.title', $popup).css('color', typologyClass.color)
        })

    unrender: (id) -> _renderQueue.add id, ->
      df = Q.defer()
      AtlasManager.unrenderEntity(id)
      df.resolve()
      df.promise

    beforeAtlasUnload: -> resetRenderQueue()