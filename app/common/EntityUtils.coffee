@EntityUtils = {}

evalEngine = null
getEvalEngine = -> evalEngine ?= new EvaluationEngine(schema: Entities.simpleSchema())

_.extend EntityUtils,

  evaluate: (entity, paramIds) ->
    paramIds = if Types.isArray(paramIds) then paramIds else [paramIds]
    typologyClass = Entities.getTypologyClass(entity)
    Entities.mergeTypology(entity)
    getEvalEngine().evaluate(model: entity, paramIds: paramIds, typologyClass: typologyClass)

if Meteor.isClient

  _renderQueue = null
  resetRenderQueue = ->
    _renderQueue?.clear()
    _renderQueue = new DeferredQueueMap()
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
      GeometryUtils.buildGeometryFromFile(fileId, {collectionId: collectionId})

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
      geoEntity = AtlasManager.getEntity(id)
      # All the geometry added during rendering. If rendering fails, these are all discarded.
      addedGeometry = []
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
              _.each geometries, (geometry) -> addedGeometry.push(geometry) if geometry
              if isPathway
                geoEntity = geometries[0]
                # A pathway doesn't have any 3d geometry or a lot.
                @_setUpEntity(geoEntity)
                df.resolve(geoEntity)
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
                          addedGeometry.push(geoEntity)
                          args.height? && entity2d.setHeight(args.height)
                          args.elevation? && entity2d.setElevation(args.elevation)
                          geoEntityDf.resolve(geoEntity)
                        geoEntityDf.reject
                      )
                    geoEntityDf.promise.then(
                      (geoEntity) =>
                        if entity3d
                          geoEntity.setForm(Feature.DisplayMode.MESH, entity3d)
                        _.each geoEntity.getForms(), (form) ->
                          form.setCentroid(lotCentroid)
                          # Apply rotation based on the azimuth.
                          form.setRotation(new Vertex(0, 0, azimuth)) if azimuth?
                        geoEntity.setDisplayMode(Session.get('entityDisplayMode'))
                        @_setUpEntity(geoEntity)
                        df.resolve(geoEntity)
                      df.reject
                    )
                df.reject
              )
            df.reject
          )
      df.promise.fail ->
        # Remove any entities which failed to render to avoid leaving them within Atlas.
        console.error('Failed to render entity ' + id)
        _.each addedGeometry, (geometry) -> geometry.remove()
      df.promise

    _setUpEntity: (geoEntity) ->
      geoEntity.show()
      @_setUpPopup(geoEntity)

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

    renderAll: ->
      renderDfs = []
      models = Entities.findByProject().fetch()
      _.each models, (model) => renderDfs.push(@render(model._id))
      Q.all(renderDfs)

    beforeAtlasUnload: -> resetRenderQueue()
