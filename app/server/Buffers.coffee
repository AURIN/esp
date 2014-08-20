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

  fromArrayBuffer: (arrayBuffer) ->
    buffer = new Buffer(arrayBuffer.byteLength)
    view = new Uint8Array(arrayBuffer)
    for value, i in buffer
      buffer[i] = view[i]
    buffer
