@Accounts.ui.config(passwordSignupFields: 'USERNAME_ONLY')

Meteor.startup ->
  AccountsAurin.config
    afterLogin: -> Router.go('/projects')
