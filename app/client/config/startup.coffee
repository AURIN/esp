Meteor.startup ->
  Session.setDefault 'helpMode', true
  # Log form errors
  AutoForm.addHooks null, {
    onError: (name, error, template) ->
      console.error(name + ' error:', error, error.stack)
  }