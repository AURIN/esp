@AssetServer =

  import: (fileId) ->
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

  synthesize: (request) ->
    Catalyst.auth.login()
    result = Catalyst.assets.synthesize(request)
    jobId = result.jobId
    response = Async.runSync (done) ->
      new Poll().pollJob(jobId).then(
        (job) -> done(null, job)
        (err) -> done(err, null)
      )
    response.result

  downloadC3ml: (id) ->
    Catalyst.auth.login()
    Catalyst.assets.c3ml.download(id)

Meteor.methods

# TODO(aramk) Currently this uses Catalyst server methods. We will eventually change to ACS.

  'assets/import': (fileId) ->
    AssetServer.import(fileId)

  'assets/synthesize': (request) ->
    AssetServer.synthesize(request)

  'assets/formats': ->
    Catalyst.auth.login()
    Catalyst.assets.formats()

  'assets/poll': (jobId) ->
    Catalyst.auth.login()
    Catalyst.assets.poll(jobId)

  'assets/c3ml/download': (id) ->
    AssetServer.downloadC3ml(id)
