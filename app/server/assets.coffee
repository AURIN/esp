@AssetServer =

  import: (fileId) ->
    buffer = FileUtils.getBuffer(fileId)
    fileObj = Files.findOne(fileId)
    file = fileObj.original
    args = {
      filename: file.name
      contentType: file.type
      knownLength: file.size
    };
    Catalyst.auth.login()
    asset = Catalyst.assets.upload(buffer, args)
    asset

  synthesize: (request) ->
    Catalyst.auth.login()
    console.log 'Synthesizing', request
    result = Catalyst.assets.synthesize(request)
    jobId = result.jobId
    response = Async.runSync (done) ->
      new Poll().pollJob(jobId).then(
        (job) -> done(null, job)
        (err) -> done(err, null)
      )
    err = response.error
    if err
      msg = 'Synthesize failed'
      console.error msg, err
      throw new Error(err)
    response.result

  load: (assets) ->
    @synthesize
      loadAsset:
        isForSynthesis: true
        assets: assets

  getParameters: (id) ->
    result = @synthesize
      catalystRequest:
        type: 'getEntityParameterValue',
        assetId: id
    resultId = result.body.resultId
    params = @downloadJson(resultId)
    params.parameterValues

  download: (id) ->
    Catalyst.auth.login()
    Catalyst.assets.download(id)

  downloadJson: (id) ->
    Catalyst.auth.login()
    Catalyst.assets.downloadJson(id)

# TODO(aramk) Currently this uses Catalyst server methods. We will eventually change to ACS.
  downloadC3ml: (id) ->
    Catalyst.auth.login()
    Catalyst.assets.c3ml.download(id)

  downloadMetaData: (id) ->
    Catalyst.auth.login()
    Catalyst.assets.metaData.download(id)

Meteor.methods

  'assets/import': (fileId) ->
    AssetServer.import(fileId)

  'assets/synthesize': (request) ->
    AssetServer.synthesize(request)

  'assets/load': (assets) ->
    AssetServer.load(assets)

  'assets/parameters': (id) ->
    AssetServer.getParameters(id)

  'assets/formats': ->
    Catalyst.auth.login()
    Catalyst.assets.formats()

  'assets/formats/input': ->
    auth = Catalyst.auth.login()
    Catalyst.assets.inputFormats()

  'assets/formats/output': ->
    Catalyst.auth.login()
    Catalyst.assets.outputFormats()

  'assets/poll': (jobId) ->
    Catalyst.auth.login()
    Catalyst.assets.poll(jobId)

  'assets/download': (id) ->
    AssetServer.download(id)

  'assets/c3ml/download': (id) ->
    AssetServer.downloadC3ml(id)

  'assets/metaData/download': (id) ->
    AssetServer.downloadC3ml(id)
