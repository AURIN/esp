Types = {

  getTypeOf: function(object) {
    return Object.prototype.toString.call(object).slice(8, -1);
  },

  isType: function(object, type) {
    return !object ? false : this.getTypeOf(object) === type;
  },

  isObjectLiteral: function(object) {
    return this.isType(object, 'Object');
  },

  isFunction: function(object) {
    return typeof object === 'function';
  },

  isArrayLiteral: function(object) {
    return this.isType(object, 'Array');
  }

};
