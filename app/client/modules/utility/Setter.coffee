@Setter =

  merge: (args...) ->
    dest = args[0]
    args.shift()
    for arg in args
      lodash.merge(dest, arg)
    dest

  clone: (src) ->
    lodash.cloneDeep(src)
