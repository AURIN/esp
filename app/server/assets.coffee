@AssetServer =

  importFile: (fileId) ->
    buffer = FileUtils.getBuffer(fileId)
    fileObj = Files.findOne(fileId)
    file = fileObj.original
    args = {
      filename: file.name
      contentType: file.type
      knownLength: file.size
    }
    @importBuffer(buffer, args)

  importBuffer: (buffer, args) ->
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

  'assets/import/file': (fileId) ->
    AssetServer.importFile(fileId)

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

HTTP.methods

  'assets/upload':
    post: (requestData) ->
      headers = @requestHeaders
      @addHeader('Content-Type', 'application/json')
      response = Async.runSync (done) ->
        try
          stream = Meteor.npmRequire('stream')
          formidable = Meteor.npmRequire('formidable')
          IncomingForm = formidable.IncomingForm
          IncomingForm.prototype.handlePart = (part) ->
            filename = part.filename
            # Ignore fields and only handle files.
            unless filename
              return
            bufs = []
            # TODO(aramk) Use utility method for this.
            part.on 'data', (chunk) ->
              bufs.push(chunk)
            part.on 'end', ->
              buffer = Buffer.concat(bufs)
              done(null, {
                buffer: buffer,
                mime: part.mime
                filename: filename
              })
          form = new IncomingForm()
          reader = new stream.Readable()
          reader.headers = headers
          form.parse reader, (err, fields, files) -> done(err, null) if err
          reader.push(requestData)
          reader.push(null)
        catch e
          done(err, null)
      err = response.error
      throw err if err
      data = response.result
      buffer = data.buffer
      asset = AssetServer.importBuffer(buffer, {
        filename: data.filename
        contentType: data.mime,
        knownLength: buffer.length
      })
      JSON.stringify(asset)
