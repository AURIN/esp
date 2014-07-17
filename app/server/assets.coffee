Meteor.methods

  # TODO(aramk) Currently this uses Catalyst server methods. We will eventually change to ACS.

  'assets/import': (fileId) ->
#    buffer = Meteor.call 'files/getBuffer', fileId
    buffer = FileUtils.getBuffer(fileId)
    console.log 'buffer', buffer.length
#    Meteor.call 'catalyst/login'
    Catalyst.auth.login()
#    asset = CatalystAssetsUpload(buffer)
    asset = Catalyst.assets.upload(buffer)
#    asset = Meteor.call 'catalyst/assets/upload', buffer
    console.log 'asset uploaded', asset
    asset
#    data = Meteor.call 'catalyst/assets/download', asset.id
#    console.log 'data', data

  'assets/synthesize': (request) ->
    Catalyst.auth.login()
    Catalyst.assets.synthesize(request)

  'assets/formats': ->
#    Meteor.call 'catalyst/login'
    Catalyst.auth.login()
#    Meteor.call 'catalyst/assets/formats'
    Catalyst.assets.formats()

  'assets/poll': (jobId) ->
    Catalyst.auth.login()
    Catalyst.assets.poll(jobId)
