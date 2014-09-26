@Assets =

  fromFile: (fileId, args) ->
    df = Q.defer()
    Meteor.call 'assets/import', fileId, (err, result) ->
      if err
        console.error 'Asset import failed', err, fileObj
        return
      assetId = result.id
      loadAssets = {}
      loadAssets[assetId] = args.format
      Meteor.call 'assets/load', loadAssets, (err, result) ->
        if err
          df.reject(err)
        else
          df.resolve(result)
    df.promise

  toC3ml: (fileId, args) ->
    df = Q.defer()
    Assets.fromFile(fileId, args).then(
      (result) ->
        body = result.body
        c3mlId = body.c3mlId
        Meteor.call 'assets/c3ml/download', c3mlId, (err, c3mls) ->
          if err
            df.reject(err)
            return
          df.resolve({c3mls: c3mls, body: body})
      (err) -> df.reject(err)
    )
    df.promise

  formats:
    shp:
      id: 'shp'
      mimeType: 'application/zip'
    kmz:
      id: 'kmz'
      mimeType: 'application/vnd.google-earth.kmz'
