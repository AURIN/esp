Meteor.methods

  'projects/remove': (id) ->
    Projects.remove(id);
    # Collections can only be removed by ID on the client, hence we need this method.
    selector = {project: id}
    Entities.remove(selector)
    Typologies.remove(selector)
    Lots.remove(selector)
