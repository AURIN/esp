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
