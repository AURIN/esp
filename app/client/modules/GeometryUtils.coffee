@GeometryUtils =

  getModelArea: (model) ->
    areaDf = Q.defer()
    geom_2d = SchemaUtils.getParameterValue(model, 'space.geom_2d')
    if geom_2d
      GeometryUtils.getWktArea(geom_2d).then(
        (area) -> areaDf.resolve({area: area, model: model})
        areaDf.reject
      )
    else
      areaDf.resolve(null)
    areaDf.promise

  getWktArea: (wktStr) ->
    areaDf = Q.defer()
    WKT.getWKT (wkt) ->
      geometry = wkt.openLayersGeometryFromWKT(wktStr)
      areaDf.resolve(geometry.getGeodesicArea())
    areaDf.promise
