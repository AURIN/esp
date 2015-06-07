Meteor.startup ->
  _.each [Entities, Typologies, Lots, Layers], (collection) ->
    collectionId = Collections.getName(collection)
    Meteor.publish collectionId, (projectId) ->
      unless @userId then return []
      unless projectId?
        throw new Meteor.Error(500, 'No project specified when subscribing.')
      project = Projects.findOne(projectId)
      unless project
        throw new Error('Cannot find project with ID ' + projectId)
      # Only publish models for non-template projects or if the user is an admin.
      if !project.isTemplate || AccountsUtil.isAdmin(@userId)
        collection.findByProject(projectId)

Meteor.publish 'userData', ->
  return [] unless @userId
  Meteor.users.find({}, {fields: {profile: 1, emails: 1, roles: 1, username: 1}})
