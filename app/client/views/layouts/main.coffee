Template.mainLayout.helpers
  stateName: -> Session.get('stateName')
  project: -> Projects.getCurrent()

Template.mainLayout.events
  'click .close.button': ->
    Router.go('projects')
    Projects.setCurrentId(null)
  'click .edit.button': ->
    Template.design.setUpFormPanel null, Template.projectForm, Projects.getCurrent()
#    Router.go 'projectEdit', {_id: Projects.getCurrentId()}
  'click .import.button': ->
    Template.design.setUpFormPanel null, Template.importForm
