# All requests to catalyst-server on infradev must contain this header.
CATALYST_SERVER_AUTH_HEADER = process.env.CATALYST_SERVER_AUTH_HEADER

request = Meteor.npmRequire('request')
stream = Meteor.npmRequire('stream')
concat = Meteor.npmRequire('concat-stream')

@Request =

  call: (opts) ->
    opts = @mergeOptions(opts)
    Promises.runSync (done) ->
      request opts, (err, res, body) ->
        done(err, body)

  buffer: (opts) ->
    opts = @mergeOptions(opts)
    Promises.runSync (done) ->
      receiveBuffer = (buffer) -> done(null, buffer)
      concatStream = concat(receiveBuffer)
      readStream = request(opts)
      readStream.on 'error', (err) -> done(err, null)
      readStream.pipe(concatStream)

  json: (opts) ->
    body = @call(opts)
    if body == ''
      body = null
    else
      try
        body = JSON.parse(body)
      catch e
        console.log('Failed parsing to JSON', body, e)
        throw e
    body

  mergeOptions: (opts) ->
    Setter.merge({
      jar: true
      headers: {
        'Authorization': CATALYST_SERVER_AUTH_HEADER
      }
    }, opts)
