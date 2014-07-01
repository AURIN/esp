Meteor.startup ->
  # Log form errors
  AutoForm.addHooks null, {
    onError: (name, error, template) ->
      console.error(name + ' error:', error, error.stack)
  }
