Template.importForm.rendered = function() {

  var URL = 'http://infradev.eng.unimelb.edu.au/catalyst-server';
  var CATALYST_SERVER_AUTH_HEADER = 'Basic Y2F0YWx5c3Q6d2h5bm9jYXRhbHlzdA==';

  $.ajax({
    url: URL,
    headers: {
      'Authorization': CATALYST_SERVER_AUTH_HEADER
    },
    success: function() {
      console.log('login', arguments);
    },
    error: function() {
      console.log('login', arguments);
    }
  });

  var $dropzone = this.$('.dropzone');
  var dropzone = new Dropzone($dropzone[0], {
    dictDefaultMessage: 'Drop a file here or click to upload.',
    addRemoveLinks: false
  });

//  Meteor.call('catalyst/login', function() {
//    console.log('login', arguments);
//  });

  dropzone.on('success', function(file, result) {
    console.log('success', arguments);
  });

};
