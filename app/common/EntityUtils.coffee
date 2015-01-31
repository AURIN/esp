@EntityUtils = {}
evalEngine = null

Meteor.startup ->
  evalEngine = new EvaluationEngine(schema: Entities.simpleSchema())

_.extend EntityUtils,

  evaluate: (entity, paramIds) ->
    paramIds = if Types.isArray(paramIds) then paramIds else [paramIds]
    typologyClass = Entities.getTypologyClass(entity)
    Entities.mergeTypology(entity)
    changes = evalEngine.evaluate(model: entity, paramIds: paramIds, typologyClass: typologyClass)

if Meteor.isClient

  _renderQueue = null
  resetRenderQueue = -> _renderQueue = new DeferredQueueMap()
  Meteor.startup -> resetRenderQueue()

  _.extend EntityUtils,

    toGeoEntityArgs: (id, args) ->
      AtlasConverter.getInstance().then (converter) ->
        entity = Entities.getFlattened(id)
        typology = Typologies.findOne(entity.typology)
        typologyClass = Entities.getTypologyClass(id)
        space = entity.parameters.space
        typologySpace = typology.parameters.space
        args = _.extend({
          id: id
          vertices: space?.geom_2d ? typologySpace?.geom_2d
          height: space?.height ? 5
          zIndex: 1
          displayMode: displayMode
          style:
            fillColor: '#ccc'
            borderColor: '#666'
        }, args)
        if typologyClass == 'PATHWAY'
          widthParamId = 'space.width'
          evalEngine.evaluate(model: entity, paramIds: [widthParamId], typologyClass: typologyClass)
          args.width = SchemaUtils.getParameterValue(entity, widthParamId)
          args.style.fillColor = '#000'
          displayMode = 'line'
        else
          displayMode = Session.get('entityDisplayMode')
        converter.toGeoEntityArgs(args)

    _getGeometryFromFile: (id, paramId) ->
      paramId ?= 'geom_3d'
      entity = Entities.getFlattened(id)
      fileId = SchemaUtils.getParameterValue(entity, 'space.' + paramId)
      if fileId then Files.downloadJson(fileId) else Q.when(null)

    _buildGeometryFromFile: (id, paramId) ->
      paramId ?= 'geom_3d'
      entity = Entities.getFlattened(id)
      fileId = SchemaUtils.getParameterValue(entity, 'space.' + paramId)
      unless fileId
        return Q.when(null)
      collectionId = id + '-' + paramId
      GeometryUtils.buildGeometryFromFile(fileId, {collectionId: collectionId})
      # df = Q.defer()
      # # geoEntity = AtlasManager.getEntity(id)
      # require ['atlas/model/GeoPoint'], (GeoPoint) =>
      #   @_getGeometryFromFile(id, paramId).then (result) ->
      #     unless result
      #       df.resolve(null)
      #       return
      #     # Modify the ID of c3ml entities to allow reusing them for multiple collections.
      #     c3mls = _.map result.c3mls, (c3ml) ->
      #       c3ml.id = collectionId + ':' + c3ml.id
      #       c3ml.show = true
      #       c3ml
      #     # Ignore all collections in the c3ml, since they don't affect visualisation.
      #     c3mls = _.filter c3mls, (c3ml) -> c3ml.type != 'collection'
      #     try
      #       c3mlEntities = AtlasManager.renderEntities(c3mls)
      #     catch e
      #       console.error('Error when rendering mesh entities', e)
      #     ids = []
      #     _.each c3mlEntities, (c3mlEntity) ->
      #       mesh = null
      #       if c3mlEntity.getForm
      #         mesh = c3mlEntity.getForm()
      #         ids.push(c3mlEntity.getId()) if mesh
      #     AtlasManager.createCollection(collectionId, ids).then(df.resolve, df.reject)
      # df.promise

    _render2dGeometry: (id) ->
      entity = Entities.getFlattened(id)
      geom_2d = SchemaUtils.getParameterValue(entity, 'space.geom_2d')
      unless geom_2d
        return Q.when(null)
      df = Q.defer()
      WKT.getWKT (wkt) =>
        isWKT = wkt.isWKT(geom_2d)
        if isWKT
          @toGeoEntityArgs(id, {show: false}).then (entityArgs) =>
            geoEntity = AtlasManager.renderEntity(entityArgs)
            df.resolve(geoEntity)
        else
          @_buildGeometryFromFile(id, 'geom_2d').then(df.resolve, df.reject)
      df.promise

    _render3dGeometry: (id) -> @_buildGeometryFromFile(id, 'geom_3d')

    _renderLot: (id) ->
      df = Q.defer()
      entity = Entities.findOne(id)
      lot = Lots.findOne(entity.lot)
      unless lot
        EntityUtils.unrender(id)
        throw new Error('Rendered geoEntity does not have an accompanying lot.')
      lotId = lot._id
      LotUtils.render(lotId).then(df.resolve, df.reject)
      df.promise

    render: (id) -> _renderQueue.add(id, => @_render(id))

    _render: (id) ->
      df = Q.defer()
      geoEntity = AtlasManager.getEntity(id)
      if geoEntity
        AtlasManager.showEntity(id)
        df.resolve(geoEntity)
      else
        entity = Entities.getFlattened(id)
        geom_2d = SchemaUtils.getParameterValue(entity, 'space.geom_2d')
        azimuth = SchemaUtils.getParameterValue(entity, 'orientation.azimuth')

        typologyClass = Entities.getTypologyClass(id)
        isPathway = typologyClass == 'PATHWAY'

        WKT.getWKT (wkt) =>
          isWKT = wkt.isWKT(geom_2d)
        
          geometryDfs = [@_render2dGeometry(id)]
          unless isPathway
            geometryDfs.push(@_render3dGeometry(id))
          Q.all(geometryDfs).then(
            (geometries) =>
              if isPathway
                # A pathway doesn't have any 3d geometry or a lot.
                df.resolve(geometries[0])
                return
              @_renderLot(id).then(
                (lotEntity) =>
                  # If the geoEntity was rendered using the Typology geometry, centre it based on the Lot.
                  lotCentroid = lotEntity.getCentroid()

                  require [
                    'atlas/model/Feature',
                    'atlas/model/Vertex'
                  ], (Feature, Vertex) =>

                    # Precondition: 2d geometry is a required for entities.
                    entity2d = geometries[0]
                    entity3d = geometries[1]
                    unless entity2d || entity3d
                      df.resolve(null)
                      return

                    # This feature will be used for rendering the 2d geometry as the
                    # footprint/extrusion and the 3d geometry as the mesh.
                    geoEntityDf = Q.defer()
                    if isWKT
                      geoEntityDf.resolve(entity2d)
                    else
                      # If we construct the 2d geometry from a collection of entities rather than
                      # WKT, the geometry is a collection rather than a feature. Create a new
                      # feature to store both 2d and 3d geometries.
                      @toGeoEntityArgs(id, {vertices: null}).then(
                        (args) ->
                          geoEntity = AtlasManager.renderEntity(args)
                          geoEntity.setForm(Feature.DisplayMode.FOOTPRINT, entity2d)
                          args.height && entity2d.setHeight(args.height)
                          args.elevation && entity2d.setElevation(args.elevation)
                          geoEntityDf.resolve(geoEntity)
                        geoEntityDf.reject
                      )
                      # geoEntity = AtlasManager.renderEntities([{
                      #   # Ensure the ID of the feature is that of the entity so show/hide works.
                      #   # The geom_2d has a different ID unless constructed from WKT.
                      #   id: id
                      #   type: 'feature'
                      #   # footprint: entity2d
                      #   # mesh: entity3d
                      # }])[0]
                    geoEntityDf.promise.then(
                      (geoEntity) =>
                        if entity3d
                          geoEntity.setForm(Feature.DisplayMode.MESH, entity3d)
                        _.each geoEntity.getForms(), (form) ->
                          form.setCentroid(lotCentroid)
                          # Apply rotation based on the azimuth.
                          form.setRotation(new Vertex(0, 0, azimuth)) if azimuth?
                        geoEntity.setDisplayMode(Session.get('entityDisplayMode'))
                        geoEntity.show()
                        @_setUpPopup(geoEntity)
                        df.resolve(geoEntity)
                      df.reject
                    )
                df.reject
              )
            df.reject
          )
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
