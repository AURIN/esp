@ArrayBuffers =

  stringToBufferArray: (str) ->
    buf = new ArrayBuffer(str.length * 2) # 2 bytes for each char
    bufView = new Uint16Array(buf)
    for i in [0..str.length]
      bufView[i] = str.charCodeAt(i)
    buf
