Meteor.startup ->
  window.document.title = AppConfig.name
  Session.setDefault 'helpMode', true
  # Used to remove loaders during debugging in the browser.
  window.hideLoaders = -> $('.loader').hide()

  Notifications.config
    Logger:
      level: 'error'
