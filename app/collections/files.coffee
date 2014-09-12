@Files = new FS.Collection 'files', stores: [new FS.Store.FileSystem('files')]

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
  fileDf = fileCache[fileId]
  if fileDf
    fileDf.promise.then (data) -> Setter.clone(data)
  else
    fileDf = Q.defer()
    fileCache[fileId] = fileDf
    Meteor.call method, fileId, (err, data) =>
      if err
        fileDf.reject(err)
      else
        fileDf.resolve(data)
  fileDf.promise

Files.download = (fileId) -> download('files/download/string', fileId)
Files.downloadJson = (fileId) -> download('files/download/json', fileId)
