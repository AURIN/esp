@LotServer =

  fromFile: (fileId) ->
    asset = AssetServer.import 'assets/import', fileId
    assetId = asset.id
    console.log 'result', job
    assets = [job];
    loadAssets = {}
    for asset in assets
      loadAssets[assetId] = format
    request = {
      loadAsset: {
        isForSynthesis: true,
        assets: loadAssets
      }
    }
    console.log 'synthesize', request
    job = AssetServer.synthesize request
    body = job.body
    console.log 'synthesize', body.length
    c3mls = AssetServer.downloadC3ml assetId
    # TODO(aramk) Download meta-data to get the names of the entities.
    console.debug('c3ml', c3mls.length)
    response = Async.runSync (done) ->
      # TODO(aramk) Handle error and pass back
      Lots.fromC3ml c3mls, (lotIds) ->
        console.debug('lotIds', lotIds)
        done(null, lotIds)
    response.result

Meteor.methods

  'lots/from/file': LotServer.fromFile

#  'lots/from/c3ml': (c3mls) ->
#    lotIds = []
#    for c3ml in c3mls
#      polygon = c3ml.polygon
#      unless polygon?
#        continue
#      wktString = ''
#      id = Lots.insert({
#        parameters:
#          general:
#            geom: wktString
#      })
#      lotIds.push(id)
#    lotIds
