Meteor.startup ->
  window.document.title = AppConfig.name
  Session.setDefault 'helpMode', true
  # Log form errors
  AutoForm.addHooks null,
    onError: (name, error) ->
      Logger.error('Form error:' + error, error.stack)
  # Used to remove loaders during debugging in the browser.
  window.hideLoaders = -> $('.loader').hide()

  Notifications.config
    Logger:
      level: 'error'
