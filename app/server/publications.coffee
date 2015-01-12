Meteor.startup ->
  _.each [Entities, Typologies, Lots], (collection) ->
    collectionId = Collections.getName(collection)
    Meteor.publish collectionId, (projectId) ->
      unless projectId
        throw new Error('No project specified when subscribing.')
      collection.findByProject(projectId)

Meteor.publish 'userData', ->
  Meteor.users.find({}, {fields: {profile: 1, emails: 1, roles: 1, username: 1}})
