Meteor.startup ->
  users = JSON.parse(Assets.getText('users.json'))
  AccountsLocal.config(users)
