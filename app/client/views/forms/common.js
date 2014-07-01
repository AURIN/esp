Forms = {

  // We may pass the temporary collection as an attribute to autoform templates, so we need to
  // define this to avoid errors since it is passed into the actual <form> HTML object.
  preventText: function(obj) {
    obj.toText = function() {
      return '';
    };
    return obj;
  }

};
