@Assets =

  fromFile: (fileId, args) ->
    df = Q.defer()
    Meteor.call 'assets/import', fileId, (err, result) ->
      if err
        console.error 'Asset import failed', err, fileObj
        return
      console.log 'asset', result
      assetId = result.id
      loadAssets = {}
      loadAssets[assetId] = args.format
      Meteor.call 'assets/load', loadAssets, (err, result) ->
        if err
          df.reject(err)
        else
          df.resolve(result)
    df.promise
