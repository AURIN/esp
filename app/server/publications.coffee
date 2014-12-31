Meteor.startup ->
  _.each [Entities, Typologies, Lots], (collection) ->
    collectionId = Collections.getName(collection)
    Meteor.publish collectionId, (projectId) ->
      if projectId then collection.findByProject(projectId) else collection.find()

Meteor.publish 'userData', ->
  Meteor.users.find({}, {fields: {profile: 1, emails: 1, roles: 1, username: 1}})
