Meteor.methods

  'projects/remove': (id) ->
    AuthUtils.authorize(Projects.findOne(id), @userId)
    Projects.remove(id);
    # Collections can only be removed by ID on the client, hence we need this method.
    selector = {project: id}
    Entities.remove(selector)
    Typologies.remove(selector)
    Lots.remove(selector)
    files = Files.find(selector).fetch()
    console.log('Removing files', files)
    Files.remove(selector)

  'projects/duplicate': (id) ->
    AuthUtils.authorize Projects.findOne(id), @userId, (doc, user) ->
      AuthUtils.isOwner(doc, user) || doc.isTemplate
    Promises.runSync (done) ->
      ProjectUtils.duplicate(id).then Meteor.bindEnvironment (idMaps) ->
        newProjectId = idMaps[Collections.getName(Projects)][id]
        # Set the isTemplate field to false when duplicating a template.
        Projects.update(newProjectId, {$set: {isTemplate: false}})
        done(null, newProjectId)
