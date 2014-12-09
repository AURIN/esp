class @DeferredQueue
  
  constructor: ->
    @queue = []

  wait: (index) ->
    promise = @queue[index]
    if promise
      promise
    else
      df = Q.defer()
      df.resolve()
      df.promise

  add: (callback) ->
    len = @queue.length
    df = Q.defer()
    @queue.push(df.promise)
    fin = => @queue.shift()
    execute = -> callback().then(df.resolve, df.reject)
    if len > 0
      @wait(len - 1).then(execute, df.reject).fin(fin)
    else
      execute().fin(fin)
    df.promise
