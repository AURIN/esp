@AssetServer =

  importFile: (fileId) ->
    console.log('AssetServer.importFile fileId', fileId)
    buffer = FileUtils.getBuffer(fileId)
    console.log('AssetServer.importFile importFile', buffer)
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
    try
      @poll(jobId)
    catch err
      msg = 'Synthesize failed'
      console.error msg, err
      throw err

  load: (args) ->
    args = _.extend({
      isForSynthesis: true
    }, args)
    actions = {}
    actionName = if args.geoBlobId? then 'load' else 'loadAsset'
    actions[actionName] = args
    @synthesize(actions)

  convert: (assets, formats) ->
    @synthesize
      loadAsset:
        # No need for generating c3ml and meta-data when converting.
        isForSynthesis: false
        assets: assets
      convert:
        tos: formats

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

  downloadJob: (jobId) ->
    result = @poll(jobId)
    @download(result.id)

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

  poll: (jobId) ->
    try
      Promises.runSync -> new Poll().pollJob(jobId)
    catch err
      msg = 'Polling failed'
      console.error(msg, err)
      throw err

Meteor.methods

  'assets/import/file': (fileId) -> AssetServer.importFile(fileId)
  'assets/synthesize': (request) -> AssetServer.synthesize(request)
  'assets/load': (args) -> AssetServer.load(args)
  'assets/convert': -> AssetServer.convert.apply(AssetServer, arguments)
  'assets/parameters': (id) -> AssetServer.getParameters(id)
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
  'assets/download': (id) -> AssetServer.download(id)
  'assets/c3ml/download': (id) -> AssetServer.downloadC3ml(id)
  'assets/metaData/download': (id) -> AssetServer.downloadMetaData(id)
  'assets/download/url': (id) ->
    Catalyst.auth.login()
    Catalyst.assets.getDownloadUrl(id)

# HTTP SERVER

# Limit buffering size to 100 MB.
HTTP.methodsMaxDataLength = 1024 * 1024 * 100

HTTP.methods

  '/assets/upload':
    post: (requestData) ->
      headers = @requestHeaders
      @addHeader('Content-Type', 'application/json')
      data = Promises.runSync (done) ->
        stream = Meteor.npmRequire('stream')
        formidable = Meteor.npmRequire('formidable')
        IncomingForm = formidable.IncomingForm
        # Create a multipart upload from the
        form = new IncomingForm()
        # Append all uploaded parts into a single buffer.
        form.handlePart = (part) ->
          filename = part.filename
          # Ignore fields and only handle files.
          unless filename
            return
          bufs = []
          # TODO(aramk) Use utility method for this.
          part.on 'data', (chunk) ->
            console.log('assets/upload received chunk', chunk)
            bufs.push(chunk)
          part.on 'end', ->
            buffer = Buffer.concat(bufs)
            console.log('assets/upload finished buffer', buffer)
            done(null, {
              buffer: buffer,
              mime: part.mime
              filename: filename
            })
        reader = new stream.Readable()
        # Prevent "not implemented" errors.
        reader._read = ->
        reader.headers = headers
        form.parse reader, (err, fields, files) -> done(err, null) if err
        reader.push(requestData)
        reader.push(null)
      buffer = data.buffer
      console.log('assets/upload buffer', buffer)
      asset = AssetServer.importBuffer(buffer, {
        filename: data.filename
        contentType: data.mime,
        knownLength: buffer.length
      })
      JSON.stringify(asset)

  '/assets/download/:id':
    get: (requestData) ->
      id = this.params.id
      Catalyst.auth.login()
      asset = Catalyst.assets.get(id)
      unless asset
        throw new Meteor.Error(404, 'Asset with ID ' + id + ' not found')
      @addHeader('Content-Type', asset.mimeType)
      @addHeader('Content-Disposition', 'attachment; filename="' + asset.fileName + '.' +
          asset.format + '"; size="' + asset.fileSize + '"')
      buffer = Catalyst.assets.downloadBuffer(id)
      stream = Meteor.npmRequire('stream')
      reader = new stream.Readable()
      reader._read = ->
      res = @createWriteStream()
      reader.pipe(res)
      reader.push(buffer)
      reader.push(null)

  '/files/download/:id':
    get: (requestData) ->
      id = this.params.id
      file = Files.findOne(id)
      console.log('download file', id, file)
      unless file
        throw new Meteor.Error(404, 'File with ID ' + id + ' not found')
      @addHeader('Content-Type', file.type())
      @addHeader('Content-Disposition', 'attachment; filename="' + file.name() +
          '"; size="' + file.size() + '"')
      buffer = FileUtils.getBuffer(id)
      console.log('file buffer', buffer)
      stream = Meteor.npmRequire('stream')
      reader = new stream.Readable()
      reader._read = ->
      res = @createWriteStream()
      reader.pipe(res)
      reader.push(buffer)
      reader.push(null)

