Meteor.methods

  'projects/remove': (id) ->
    Projects.remove(id);
    # Collections can only be removed by ID on the client, hence we need this method.
    selector = {project: id}
    Entities.remove(selector)
    Typologies.remove(selector)
    Lots.remove(selector)

  'projects/duplicate': (id) ->
    response = Async.runSync (done) ->
      ProjectUtils.duplicate(id).then (idMaps) ->
        newProjectId = idMaps[Collections.getName(Projects)][id]
        done(null, newProjectId)
    err = response.error
    if err
      throw new Error('Duplicating project with ID ' + id + ' failed')
    response.result
