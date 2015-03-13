Meteor.startup ->
  window.document.title = AppConfig.name
  Session.setDefault 'helpMode', true
  # Log form errors
  AutoForm.addHooks null, {
    onError: (name, error, template) ->
      console.error(name + ' error:', error, error.stack)
  }
  # Used to remove loaders during debugging in the browser.
  window.hideLoaders = -> $('.loader').hide()
