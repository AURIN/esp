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

  'files/download/string': (id) ->
    buffer = FileUtils.getBuffer(id)
    console.log(buffer)
    str = buffer.toString()
    console.log(str)
    str

#  'files/getReadStream': getReadStream
#
#  'files/getBuffer': (fileId) ->
#
#    item = Files.findOne(fileId)
#    unless item
#      throw new Meteor.Error(404, 'File with ID ' + fileId + ' not found.')
#    reader = item.createReadStream('files')
#    console.log 'stream type', Types.getTypeOf(reader)
#    Buffers.fromStream(reader)
#
##    stream = getReadStream(fileId)
##    console.log 'stream type', Types.getTypeOf(stream)
##    Buffers.fromStream(stream)
