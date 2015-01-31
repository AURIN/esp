@GeometryUtils =

  getModelArea: (model) ->
    df = Q.defer()
    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d
      @hasWktGeometry(model).then (isWKT) =>
        if isWKT
          result = @getWktArea(geom_2d)
        else
          @buildGeometryFromFile(geom_2d).then(
            (geometry) => df.resolve(geometry.getArea())
            df.reject
          )
          # Files.downloadJson(geom_2d).then
          # @getC3mlsArea(geom_2d.c3mls)
        result.then(df.resolve, df.reject)
    else
      df.resolve(null)
    df.promise

  # getC3mlsArea: (c3mls) ->
  #   df = Q.defer()
  #   # If the GeoEntity is already rendered, keep it rendered. Otherwise add it as a hidden GeoEntity
  #   # and get the area, then remove it.
  #   # id = json.id
  #   # unless id
  #   #   throw new Error('GeoEntity needs ID')
  #   # geoEntity = AtlasManager.getEntity(id)
  #   # exists = geoEntity?
  #   # unless exists

  #   # Precondition: the entities in the c3ml are not yet rendered.
  #   AtlasManager.renderEntities(c3mls).then(
  #     (entities) =>
  #       @createCollection(entities).then(
  #         (collection) -> df.resolve(collection.getArea())
  #         df.reject
  #       )
  #     df.reject
  #   )
  #   df.promise

  # getGeometryFromFile: (id, paramId) ->
  #   paramId ?= 'geom_3d'
  #   entity = Entities.getFlattened(id)
  #   fileId = SchemaUtils.getParameterValue(entity, 'space.' + paramId)
  #   if fileId then Files.downloadJson(fileId) else Q.when(null)

  buildGeometryFromFile: (fileId, args) ->
    args = _.extend({
      collectionId: fileId
    }, args)
    collectionId = args.collectionId
    df = Q.defer()
    # geoEntity = AtlasManager.getEntity(id)
    require ['atlas/model/GeoPoint'], (GeoPoint) ->
      Files.downloadJson(fileId).then (result) ->
        unless result
          df.resolve(null)
          return
        # Modify the ID of c3ml entities to allow reusing them for multiple collections.
        c3mls = _.map result.c3mls, (c3ml) ->
          c3ml.id = collectionId + ':' + c3ml.id
          c3ml.show = true
          c3ml
        # Ignore all collections in the c3ml, since they don't affect visualisation.
        c3mls = _.filter c3mls, (c3ml) -> c3ml.type != 'collection'
        try
          c3mlEntities = AtlasManager.renderEntities(c3mls)
        catch e
          console.error('Error when rendering entities', e)
        ids = []
        _.each c3mlEntities, (c3mlEntity) ->
          form = null
          if c3mlEntity.getForm
            form = c3mlEntity.getForm()
            ids.push(c3mlEntity.getId()) if form
        AtlasManager.createCollection(collectionId, ids).then(df.resolve, df.reject)
    df.promise

  # createCollection: (entities) ->
  #   ids = _.map entities, (entity) -> entity.getId()
  #   AtlasManager.createCollection(ids[0] + '-collection', ids).then(df.resolve, df.reject)

  hasWktGeometry: (model) ->
    df = Q.defer()
    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d
      WKT.getWKT (wkt) -> df.resolve(wkt.isWKT(geom_2d))
    else
      df.resolve(false)
    df.promise

  getWktArea: (wktStr) ->
    df = Q.defer()
    WKT.getWKT (wkt) ->
      geometry = wkt.openLayersGeometryFromWKT(wktStr)
      df.resolve(geometry.getGeodesicArea())
    df.promise
