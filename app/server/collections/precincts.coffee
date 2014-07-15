Meteor.methods

  'precincts/remove': (id) ->
    Precincts.remove(id);
    # Collections can only be removed by ID on the client, hence we need this method.
    selector = {precinct: id}
    Entities.remove(selector)
    Typologies.remove(selector)
