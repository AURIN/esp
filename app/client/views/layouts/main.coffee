Template.mainLayout.helpers
  stateName: -> Session.get('stateName')
  precinct: -> Precincts.getCurrent()

Template.mainLayout.events
  'click .close.button': ->
    Router.go('precincts')
  'click .parameters.button': ->
    # TODO(aramk) Give params form
    Template.setUpFormPanel null, paramsForm
