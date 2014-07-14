Template.mainLayout.helpers
  stateName: -> Session.get('stateName')
  precinct: -> Session.get('precinct')

Template.mainLayout.events
  'click .close.button': ->
    Router.go('precincts')
