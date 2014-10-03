@ArrayBuffers =

  stringToBufferArray: (str) ->
    buffer = new ArrayBuffer(str.length)
    bytes = new Uint8Array(buffer)
    for i in [0..str.length]
      bytes[i] = str.charCodeAt(i)
    buffer
