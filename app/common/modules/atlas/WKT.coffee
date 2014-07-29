getWKT = (callback) ->
  require ['atlas/util/WKT'], (WKT) ->
    callback(WKT.getInstance())

@WKT =

  fromVertices: (vertices, callback) ->
    getWKT (wkt) ->
      wktString = wkt.wktFromVertices(vertices)
      callback(wktString)

  swapCoords: (coords, callback) ->
    getWKT (wkt) ->
      wkt.swapCoords(coords)
      callback(coords)
