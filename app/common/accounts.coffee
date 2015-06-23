Meteor.startup ->

  AccountsUi.config
    login:
      onSuccess: -> Router.go('/projects')
