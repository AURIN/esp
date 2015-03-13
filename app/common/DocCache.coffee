class DocCache

  constructor: (collection, generator) ->
    @collection = collection
    @generator = generator
    @data = {}
    remove = (doc) => @remove(doc._id)
    @handle = Collections.observe(collection, {
      changed: remove
      removed: remove
    })

  get: (id) ->
    data = @data[id]
    if data
      return Q.when(data)
    Q.when(@generator(id)).then (datum) ->
      data[id] = datum

  remove: (id) ->
    datum = @data[id]
    delete @data[id]
    datum

  destroy: -> @handle.stop()
