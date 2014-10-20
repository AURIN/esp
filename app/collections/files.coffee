# TODO(aramk) Add security and ownership.

Meteor.startup ->
  Meteor.call 'config/filesystem/path', (err, filesPath) ->

    # Set up cfs directory for Modulus.
    fileSystemArgs = {}
    if filesPath?
      cfsPath = filesPath + '/cfs'
      fileSystemArgs.path = cfsPath
      console.log('Using ' + cfsPath + ' for cfs directory.')
    else
      console.log('Using default cfs directory.')

    @Files = new FS.Collection 'files', stores: [
      new FS.Store.FileSystem('files', fileSystemArgs)
    ]

    Files.allow
      download: Collections.allow
      insert: Collections.allow
      update: Collections.allow
      remove: Collections.allow

    # File IDs to deferred promises containing their data.
    fileCache = {}

    download = (method, fileId) ->
      unless fileId?
        throw new Error('No file ID given')
      fileDf = Q.defer()
      cacheDf = fileCache[fileId]
      unless cacheDf
        cacheDf = fileCache[fileId] = Q.defer()
        Meteor.call method, fileId, (err, data) =>
          if err
            cacheDf.reject(err)
          else
            cacheDf.resolve(data)
      cacheDf.promise.then(
        (data) -> fileDf.resolve(Setter.clone(data))
        fileDf.reject
      )
      fileDf.promise

    Files.download = (fileId) -> download('files/download/string', fileId)
    Files.downloadJson = (fileId) -> download('files/download/json', fileId)

    Files.upload = (obj) ->
      df = Q.defer()
      Files.insert obj, (err, fileObj) ->
        if err
          df.reject(err)
          return
        # TODO(aramk) Remove timeout and use an event callback.
        timerHandler = ->
          progress = fileObj.uploadProgress()
          uploaded = fileObj.isUploaded()
          if uploaded
            clearTimeout(handle)
            df.resolve(fileObj)
        handle = setInterval timerHandler, 1000
      df.promise

if Meteor.isServer

  @FileUtils =

    getReadStream: (fileId) ->
      item = Files.findOne(fileId)
      unless item
        throw new Meteor.Error(404, 'File with ID ' + fileId + ' not found.')
      item.createReadStream('files')

    getBuffer: (fileId) ->
      reader = @getReadStream(fileId)
      Buffers.fromStream(reader)

  Meteor.methods

    'files/download/string': (id) -> FileUtils.getBuffer(id).toString()
    'files/download/json': (id) -> JSON.parse(FileUtils.getBuffer(id).toString())
