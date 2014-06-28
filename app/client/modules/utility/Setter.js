Setter = {

  merge: function() {
    var args = Array.prototype.slice.apply(arguments);
    var dest = this.clone(args[0]);
    for (var i = 1; i < args.length; i++) {
      _.extend(dest, args[i]);
    }
    return dest;
  },

  clone: function(src) {
    // Adapted from dojo/lang.
    if (!src || !Types.isObjectLiteral(src) || Types.isFunction(src)) {
      // null, undefined, any non-object, or function
      return src;	// anything
    }
    if (src.nodeType && 'cloneNode' in src) {
      // DOM Node
      return src.cloneNode(true); // Node
    }
    if (src instanceof Date) {
      // Date
      return new Date(src.getTime());	// Date
    }
    if (src instanceof RegExp) {
      // RegExp
      return new RegExp(src);   // RegExp
    }
    var r, i, l;
    if (Types.isArrayLiteral(src)) {
      // array
      r = [];
      for (i = 0, l = src.length; i < l; ++i) {
        if (i in src) {
          r.push(this.clone(src[i]));
        }
      }
      // we don't clone functions for performance reasons
      //		}else if(d.isFunction(src)){
      //			// function
      //			r = function(){ return src.apply(this, arguments); };
    } else {
      // generic objects
      r = src.constructor ? new src.constructor() : {};
    }
    return _.extend(r, src);
  }

};
