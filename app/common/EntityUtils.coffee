@EntityUtils = {}
bindMeteor = Meteor.bindEnvironment.bind(Meteor)

evalEngine = null
getEvalEngine = -> evalEngine ?= new EvaluationEngine(schema: Entities.simpleSchema())
FILL_COLOR = '#fff'
BORDER_COLOR = '#666'

_.extend EntityUtils,

  evaluate: (entity, paramIds) ->
    paramIds = if Types.isArray(paramIds) then paramIds else [paramIds]
    typologyClass = Entities.getTypologyClass(entity)
    Entities.getFlattened(entity)
    getEvalEngine().evaluate(model: entity, paramIds: paramIds, typologyClass: typologyClass)

if Meteor.isClient

  _renderQueue = null
  resetRenderQueue = ->
    _renderQueue?.clear()
    _renderQueue = new DeferredQueueMap()
  Meteor.startup -> resetRenderQueue()

  renderCount = new ReactiveVar(0)
  incrementRenderCount = -> renderCount.set(renderCount.get() + 1)
  decrementRenderCount = -> renderCount.set(renderCount.get() - 1)

  _.extend EntityUtils,

    toGeoEntityArgs: (id, args) ->
      AtlasConverter.getInstance().then bindMeteor (converter) ->
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
            fillColor: FILL_COLOR
            borderColor: BORDER_COLOR
        }, args)
        if typologyClass == 'PATHWAY'
          widthParamId = 'space.width'
          getEvalEngine()
              .evaluate(model: entity, paramIds: [widthParamId], typologyClass: typologyClass)
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
      style =
        fillColor: FILL_COLOR
        borderColor: BORDER_COLOR
      GeometryUtils.buildGeometryFromFile fileId,
        collectionId: collectionId
        style: style
        show: false

    _render2dGeometry: (id) ->
      entity = Entities.getFlattened(id)
      geom_2d = SchemaUtils.getParameterValue(entity, 'space.geom_2d')
      unless geom_2d
        return Q.when(null)
      df = Q.defer()
      WKT.getWKT bindMeteor (wkt) =>
        isWKT = wkt.isWKT(geom_2d)
        if isWKT
          @toGeoEntityArgs(id, {show: false}).then bindMeteor (entityArgs) =>
            geoEntity = AtlasManager.renderEntity(entityArgs)
            df.resolve(geoEntity)
        else
          @_buildGeometryFromFile(id, 'geom_2d').then(df.resolve, df.reject)
      df.promise

    _render3dGeometry: (id) -> @_buildGeometryFromFile(id, 'geom_3d')

    _getRenderCentroid: (id) ->
      df = Q.defer()
      entity = Entities.findOne(id)
      position = SchemaUtils.getParameterValue(entity, 'space.position')
      if position
        requirejs [
          'atlas/model/GeoPoint'
        ], bindMeteor (GeoPoint) ->
          df.resolve(new GeoPoint(position))
      else
        @_renderLot(id).then bindMeteor (lotEntity) ->
          # If the geoEntity was rendered using the Typology geometry, centre it based on the Lot.
          df.resolve(lotEntity.getCentroid())
      df.promise

    _renderLot: (id) ->
      entity = Entities.findOne(id)
      lotId = entity.lot
      lot = Lots.findOne(lotId)
      unless lot
        EntityUtils.unrender(id)
        return Q.reject('Rendered geoEntity ' + id + ' does not have an accompanying lot ' + lotId)
      LotUtils.render(lotId)

    render: (id) -> _renderQueue.add(id, => @_render(id))

    _render: (id) ->
      df = Q.defer()
      incrementRenderCount()
      df.promise.fin -> decrementRenderCount()
      resolve = (geoEntity) ->
        if geoEntity
          geoEntity.ready().then -> df.resolve(geoEntity)
        else
          df.resolve(geoEntity)
      geoEntity = AtlasManager.getEntity(id)
      # All the geometry added during rendering. If rendering fails, these are all discarded.
      addedGeometry = []
      if geoEntity
        AtlasManager.showEntity(id)
        resolve(geoEntity)
      else
        entity = Entities.getFlattened(id)
        geom_2d = SchemaUtils.getParameterValue(entity, 'space.geom_2d')
        azimuth = SchemaUtils.getParameterValue(entity, 'orientation.azimuth')

        typologyClass = Entities.getTypologyClass(id)
        isPathway = typologyClass == 'PATHWAY'

        WKT.getWKT bindMeteor (wkt) =>
          isWKT = wkt.isWKT(geom_2d)
        
          geometryDfs = [@_render2dGeometry(id)]
          unless isPathway
            geometryDfs.push(@_render3dGeometry(id))
          Q.all(geometryDfs).then(
            bindMeteor (geometries) =>
              _.each geometries, (geometry) -> addedGeometry.push(geometry) if geometry
              if isPathway
                geoEntity = geometries[0]
                # A pathway doesn't have any 3d geometry or a lot.
                @_setUpEntity(geoEntity)
                resolve(geoEntity)
                return
              @_getRenderCentroid(id).then(
                bindMeteor (centroid) =>

                  requirejs [
                    'atlas/model/Feature',
                    'atlas/model/GeoEntity',
                    'atlas/model/Vertex'
                  ], bindMeteor (Feature, GeoEntity, Vertex) =>

                    # Precondition: 2d geometry is a required for entities.
                    entity2d = geometries[0]
                    entity3d = geometries[1]
                    unless entity2d || entity3d
                      # If the entity belongs to an Open Space precinct, generate an empty GeoEntity
                      # to remove special cases.
                      if typologyClass == 'OPEN_SPACE'
                        @_getBlankFeatureArgs(id).then bindMeteor (entityArgs) =>
                          resolve(AtlasManager.renderEntity(entityArgs))
                      else
                        resolve(null)
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
                      @_getBlankFeatureArgs(id).then(
                        bindMeteor (args) ->
                          geoEntity = AtlasManager.renderEntity(args)
                          addedGeometry.push(geoEntity)
                          if entity2d
                            geoEntity.setForm(Feature.DisplayMode.FOOTPRINT, entity2d)
                            args.height? && entity2d.setHeight(args.height)
                            args.elevation? && entity2d.setElevation(args.elevation)
                          geoEntityDf.resolve(geoEntity)
                        geoEntityDf.reject
                      )
                    geoEntityDf.promise.then(
                      bindMeteor (geoEntity) =>
                        if entity3d
                          geoEntity.setForm(Feature.DisplayMode.MESH, entity3d)
                        formDfs = []
                        _.each geoEntity.getForms(), (form) ->
                          # if form.isGltf && form.isGltf()
                          # Show the entity to ensure we can transform the rendered models. GLTF
                          # meshes need to be rendered before we can determine their centroid.
                          # TODO(aramk) Build the geometry without having to show it.
                          form.show()
                          form.hide()
                            # readyPromise = form.ready()
                          formDfs.push form.ready().then ->
                            # Apply rotation based on the azimuth. Use the lot centroid since the
                            # centroid may not be updated yet for certain models (e.g. GLTF meshes).
                            currentCentroid = form.getCentroid()
                            # Perform this after getting the centroid to avoid rebuiding the
                            # primitive for GLTF meshes, which would require another ready() call.
                            form.setCentroid(centroid)
                            newCentroid = centroid.clone()
                            # Set the elevation to the same as the current elevation to avoid any
                            # movement in the elevation axis.
                            newCentroid.elevation = currentCentroid.elevation
                            form.setRotation(new Vertex(0, 0, azimuth), newCentroid) if azimuth?
                            # form.hide()
                        Q.all(formDfs).then =>
                          geoEntity.setDisplayMode(Session.get('entityDisplayMode'))
                          geoEntity.show()
                          @_setUpEntity(geoEntity)
                          resolve(geoEntity)
                      df.reject
                    )
                df.reject
              )
            df.reject
          )
      df.promise.fail ->
        # Remove any entities which failed to render to avoid leaving them within Atlas.
        Logger.error('Failed to render entity ' + id)
        _.each addedGeometry, (geometry) -> geometry.remove()
      df.promise

    _getBlankFeatureArgs: (id) -> @toGeoEntityArgs(id, {vertices: null})

    _setUpEntity: (geoEntity) ->
      geoEntity.show()
      # Server doesn't need popups.
      if Meteor.isClient then @_setUpPopup(geoEntity)

    _setUpPopup: (geoEntity) ->
      entity = Entities.getFlattened(AtlasIdMap.getAppId(geoEntity.getId()))
      typology = Typologies.findOne(entity.typology)
      typologyClassId = SchemaUtils.getParameterValue(entity, 'general.class')
      typologyClass = Typologies.Classes[typologyClassId]
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

    unrender: (id) -> _renderQueue.add id, -> AtlasManager.unrenderEntity(id)

    renderAll: ->
      renderDfs = []
      models = Entities.findByProject().fetch()
      _.each models, (model) => renderDfs.push(@render(model._id))
      Q.all(renderDfs)

    beforeAtlasUnload: ->
      resetRenderQueue()
      @resetRenderCount()

    getRenderCount: -> renderCount.get()

    resetRenderCount: -> renderCount.set(0)
