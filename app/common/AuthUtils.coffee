@AuthUtils =
  
  _resolveUser: (user) ->
    if Types.isString(user)
      user = Meteor.users.findOne(user)
    else
      user ?= Meteor.user()
    user
  
  isOwner: (doc, user) ->
    user = @_resolveUser(user)
    doc.author == user.username

  authorize: (doc, user, predicate) ->
    user = @_resolveUser(user)
    if predicate
      result = predicate(doc, user)
    else
      result = @isOwner(doc, user) || @isAdmin(user)
    unless result
      throw new Meteor.Error(403, 'Access denied')

  isAdmin: (user) ->
    user = @_resolveUser(user)
    Roles.userIsInRole(user, 'admin')

