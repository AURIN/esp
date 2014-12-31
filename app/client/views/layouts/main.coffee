Template.mainLayout.helpers
  appName: -> AppConfig.name
  stateName: -> Session.get('stateName')
  project: -> Projects.getCurrent()

Template.mainLayout.events
  'click .header .close.button': ->
    Router.go('projects')
    Projects.setCurrentId(null)
  'click .header .edit.button': ->
    Template.design.addFormPanel null, Template.projectForm, Projects.getCurrent()
  'click .header .import.button': -> Template.design.addFormPanel null, Template.importForm
  'click .header .zoom.button': -> LotUtils.renderAllAndZoom()
