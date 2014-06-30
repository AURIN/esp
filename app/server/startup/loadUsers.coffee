loadUser = (user) ->
  userAlreadyExists = typeof Meteor.users.findOne({ username: user.username }) == 'object';
  if !userAlreadyExists
    Accounts.createUser(user)

Meteor.startup ->
  users = YAML.eval(Assets.getText('users.yml'))
  for own username, user of users
    loadUser(user)
