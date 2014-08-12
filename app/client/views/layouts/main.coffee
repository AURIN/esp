Template.mainLayout.helpers
  stateName: -> Session.get('stateName')
  project: -> Projects.getCurrent()

Template.mainLayout.events
  'click .project > .close.button': ->
    Router.go('projects')
    Projects.setCurrentId(null)
  'click .project > .edit.button': ->
    Template.design.setUpFormPanel null, Template.projectForm, Projects.getCurrent()
  'click .project > .import.button': -> Template.design.setUpFormPanel null, Template.importForm
  'click .project > .zoom.button': -> AtlasManager.zoomToProject()
