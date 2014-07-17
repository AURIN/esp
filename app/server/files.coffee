Meteor.methods

  'files/getData': (fileId) ->
    item = Files.findOne(fileId)
    unless item
      throw new Meteor.Error(404, 'File with ID ' + fileId + ' not found.')
    reader = item.createReadStream('files')
    result = Async.runSync (done) ->
      data = ''
      reader.on 'data', (buffer) ->
        data += buffer.toString()
      reader.on 'end', ->
        done(null, data)
    result.result
