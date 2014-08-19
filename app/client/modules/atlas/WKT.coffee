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
    Assets.fromFile(fileId, args).then(
      (result) ->
        body = result.body
        Meteor.call 'assets/c3ml/download', body.c3mlId, (err, c3mls) ->
          if err
            df.reject(err)
            return
          console.log('c3mls', c3mls)
          wktResults = {}
          wktDfs = []
          _.each c3mls, (c3ml) ->
            if c3ml.type != 'polygon'
              return
            id = c3ml.id
            coords = _.map c3ml.coordinates, (coord) -> {longitude: coord.x, latitude: coord.y}
            wktDf = Q.defer()
            wktDfs.push(wktDf.promise)
            WKT.fromVertices coords, (wkt) ->
              console.log('wkt', wkt)
              wktResults[id] = wkt
              wktDf.resolve(wkt)
          Q.all(wktDfs).then ->
            console.log('wktResults', wktResults)
            df.resolve(wktResults)
      (err) -> df.reject(err)
    )
    df.promise

