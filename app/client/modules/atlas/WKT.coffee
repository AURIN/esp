getWKT = (callback) ->
  require ['atlas/util/WKT'], (WKT) ->
    callback(WKT.getInstance())

@WKT =

  fromVertices: (vertices, callback) ->
    getWKT (wkt) ->
      wktString = wkt.wktFromVertices(vertices)
      callback(wktString)

  fromFile: (fileId, args) ->
    df = Q.defer()
    Assets.toC3ml(fileId, args).then(
      (result) ->
        wktResults = {}
        wktDfs = []
        _.each result.c3mls, (c3ml) ->
          if c3ml.type != 'polygon'
            return
          id = c3ml.id
          wktDf = WKT.fromC3ml(c3ml).then (wkt) ->
            wktResults[id] = wkt
          wktDfs.push(wktDf)
        Q.all(wktDfs).then ->
          df.resolve(wktResults)
      (err) -> df.reject(err)
    )
    df.promise

  fromC3ml: (c3ml) ->
    df = Q.defer()
    type = c3ml.type
    if type != 'polygon'
      df.reject('c3ml must be polygon, not ' + type)
      return df.promise
    coords = _.map c3ml.coordinates, (coord) -> {longitude: coord.x, latitude: coord.y}
    WKT.fromVertices coords, (wkt) ->
      df.resolve(wkt)
    df.promise

