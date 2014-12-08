Meteor.publish 'projects', -> Projects.find()
Meteor.publish 'files', -> Files.find()
Meteor.startup ->
  _.each [Entities, Typologies, Lots], (collection) ->
    collectionId = Collections.getName(collection)
    Meteor.publish collectionId, (projectId) ->
      if projectId then collection.findByProject(projectId) else collection.find()
