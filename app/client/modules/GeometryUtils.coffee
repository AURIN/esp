@GeometryUtils =

  getModelArea: (model) ->
    df = Q.defer()
    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d
      @hasWktGeometry(model).then (isWKT) =>
        if isWKT
          promise = @getWktArea(geom_2d)
        else
          # Create a temporary geometry and check the area.
          promise = @buildGeometryFromFile(geom_2d, {show: false}).then(
            (geometry) =>
              area = geometry.getArea()
              geometry.remove()
              df.resolve(area)
            df.reject
          )
        promise.then(df.resolve, df.reject)
    else
      df.resolve(null)
    df.promise

  buildGeometryFromFile: (fileId, args) ->
    args = _.extend({
      collectionId: fileId
      show: true
    }, args)
    collectionId = args.collectionId
    df = Q.defer()
    require ['atlas/model/GeoPoint'], (GeoPoint) ->
      Files.downloadJson(fileId).then (result) ->
        unless result
          df.resolve(null)
          return
        # Modify the ID of c3ml entities to allow reusing them for multiple collections.
        c3mls = _.map result.c3mls, (c3ml) ->
          c3ml.id = collectionId + ':' + c3ml.id
          c3ml.show = args.show
          c3ml
        # Ignore all collections in the c3ml, since they don't affect visualisation.
        c3mls = _.filter c3mls, (c3ml) -> c3ml.type != 'collection'
        try
          c3mlEntities = AtlasManager.renderEntities(c3mls)
        catch e
          console.error('Error when rendering entities', e)
        ids = _.map c3mlEntities, (c3mlEntity) -> c3mlEntity.getId()
        AtlasManager.createCollection(collectionId, ids).then(df.resolve, df.reject)
    df.promise

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
