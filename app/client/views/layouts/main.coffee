Template.mainLayout.helpers
  stateName: -> Session.get('stateName')
  project: -> Projects.getCurrent()

Template.mainLayout.events
  'click .close.button': ->
    Router.go('projects')
    Projects.setCurrentId(null)
  'click .edit.button': ->
    Router.go 'projectEdit', {_id: Projects.getCurrentId()}
    # TODO(aramk) Give params form
#    Template.setUpFormPanel null, paramsForm
