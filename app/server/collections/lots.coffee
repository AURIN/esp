@LotServer =

  fromFile: (args) ->
    fileId = args.fileId
    format = args.format
    asset = AssetServer.import fileId
    assetId = asset.id
    console.log 'result', asset
    assets = [asset];
    loadAssets = {}
    for asset in assets
      loadAssets[assetId] = format
    request = {
      loadAsset: {
        isForSynthesis: true,
        assets: loadAssets
      }
    }
    console.log 'synthesize request', request
    response = AssetServer.synthesize request
    console.log('synthesize response', response)
    body = response.body
    console.log 'synthesize', body.length
    c3mlId = body.c3mlId
    c3mls = AssetServer.downloadC3ml c3mlId
    # TODO(aramk) Download meta-data to get the names of the entities.
    console.log('c3ml', c3mls.length)
    response = Async.runSync (done) ->
      # TODO(aramk) Handle error and pass back
      LotUtils.fromC3ml c3mls, (lotIds) ->
        console.log('lotIds', lotIds)
        done(null, lotIds)
    response.result

Meteor.methods

  'lots/from/file': LotServer.fromFile

  # TODO(aramk) Remove
  'wkt': ->
    response = Async.runSync (done) ->
      WKT.fromVertices [[0,0]], ->
        console.log('callback', arguments)
    response.result
