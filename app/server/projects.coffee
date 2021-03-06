Meteor.methods

  # Removes the given project and all related data.
  'projects/remove': (id) ->
    AccountsUtil.authorize(Projects.findOne(id), @userId)
    Projects.remove(id);
    # Collections can only be removed by ID on the client, hence we need this method.
    selector = {project: id}
    Entities.remove(selector)
    Typologies.remove(selector)
    Lots.remove(selector)

  # A custom version of projects/duplicate to handle template project logic.
  'projects/duplicate2': (id) ->
    userId = @userId
    user = Meteor.users.findOne(userId)
    AccountsUtil.authorize Projects.findOne(id), userId, (doc, user) ->
      AccountsUtil.isOwner(doc, user) || doc.isTemplate
    Logger.info('Duplicating project', id, '...')
    Promises.runSync ->
      df = Q.defer()
      duplicatePromise = ProjectUtils.duplicate id,
        callback: (json) ->
          _.each json[Collections.getName(Projects)], (project) ->
            # Set the isTemplate field to false when duplicating a template and set the user as the
            # one who duplicated it to ensure the inserting passes validation.
            project.author = userId
            project.isTemplate = false
          json
      duplicatePromise.fail(df.reject)
      duplicatePromise.then Meteor.bindEnvironment (idMaps) ->
        newProjectId = idMaps[Collections.getName(Projects)][id]
        Logger.info('Duplicated project', id, 'to new project', newProjectId)
        df.resolve(newProjectId)
      df.promise
