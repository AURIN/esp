@Files = new FS.Collection 'files', stores: [
  new FS.Store.FileSystem('files', {
    path: '/tmp/meteor-files'
  })
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
