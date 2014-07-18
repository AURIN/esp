class @KeyStore

  constructor: ->
    @data = {}

  add: (key, value) ->
    @data[key] = value

  get: (key) ->
    @data[key]

  remove: (key) ->
    delete @data[key]
