getWKT = (callback) ->
  require ['atlas/util/WKT'], (WKT) ->
    callback(WKT.getInstance())

@WKT =

  fromVertices: (vertices, callback) ->
    console.debug('WKT.fromVertices', vertices)
    getWKT (wkt) ->
      console.debug('WKT', wkt)
      wktString = wkt.wktFromVertices(vertices)
      console.debug('wkt', wktString)
      callback(wktString)

  swapCoords: (coords, callback) ->
    console.debug('WKT.swapCoords', JSON.stringify(coords))
    getWKT (wkt) ->
      console.debug('WKT', wkt)
      wkt.swapCoords(coords)
      console.debug('coords', coords)
      callback(coords)
