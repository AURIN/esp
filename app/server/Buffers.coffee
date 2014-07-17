@Buffers =

  fromStream: (stream) ->
    console.log 'stream', stream, stream.on
    response = Async.runSync (done) ->
      buffers = []
      stream.on 'data', (buffer) ->
        buffers.push(buffer)
      stream.on 'end', ->
        done(null, Buffer.concat(buffers))
    response.result
