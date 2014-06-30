@Setter =

  merge: (args...) ->
    dest = this.clone(args[0])
    args.shift()
    for arg in args
      _.extend(dest, arg)
    return dest;

  clone: (src) ->
    # Adapted from dojo/lang.
    if !src || !Types.isObjectLiteral(src) || Types.isFunction(src)
      # null, undefined, any non-object, or function
      return src # anything
    if src.nodeType && src.cloneNode
      # DOM Node
      src.cloneNode(true) # Node
    if src instanceof Date
      # Date
      new Date(src.getTime()) # Date
    if src instanceof RegExp
      # RegExp
      new RegExp(src) # RegExp
    if Types.isArrayLiteral(src)
      # array
      r = []
      for i in [0..src.length]
        if i in src
          r.push(this.clone(src[i]))
      # we don't clone functions for performance reasons
      #		}else if(d.isFunction(src)){
      #			# function
      #			r = function(){ return src.apply(this, arguments); };
    else
      # generic objects
      r = if src.constructor then new src.constructor() else {}
    _.extend(r, src)
