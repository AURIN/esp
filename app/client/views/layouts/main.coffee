Template.mainLayout.helpers
  stateName: -> Session.get('stateName')
  project: -> Projects.getCurrent()

Template.mainLayout.events
  'click .close.button': ->
    Router.go('projects')
    Projects.setCurrentId(null)
  'click .parameters.button': ->
    # TODO(aramk) Give params form
    Template.setUpFormPanel null, paramsForm
