@GeometryUtils =

  getWktArea: (wktStr) ->
    areaDf = Q.defer()
    WKT.getWKT (wkt) ->
      geometry = wkt.openLayersGeometryFromWKT(wktStr)
      areaDf.resolve(geometry.getGeodesicArea())
    areaDf.promise
