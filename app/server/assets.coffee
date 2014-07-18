Meteor.methods

  # TODO(aramk) Currently this uses Catalyst server methods. We will eventually change to ACS.

  'assets/import': (fileId) ->
    buffer = FileUtils.getBuffer(fileId)
    console.log 'buffer', buffer.length
    Catalyst.auth.login()
    fileObj = Files.findOne(fileId)
    console.log 'fileObj', fileObj
    file = fileObj.original
    args = {
      filename: file.name
      contentType: file.type
      knownLength: file.size
    };
    asset = Catalyst.assets.upload(buffer, args)
    console.log 'asset uploaded', asset
    asset

  'assets/synthesize': (request) ->
    Catalyst.auth.login()
    Catalyst.assets.synthesize(request)

  'assets/formats': ->
    Catalyst.auth.login()
    Catalyst.assets.formats()

  'assets/poll': (jobId) ->
    Catalyst.auth.login()
    Catalyst.assets.poll(jobId)
