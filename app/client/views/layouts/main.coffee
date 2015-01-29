TemplateClass = Template.mainLayout

TemplateClass.rendered = ->

TemplateClass.helpers
  appName: -> AppConfig.name
  stateName: -> Session.get('stateName')
  project: -> Projects.getCurrent()

TemplateClass.events
  'click .header .close.button': ->
    Router.go('projects')
    Projects.setCurrentId(null)
  'click .header .edit.button': ->
    Template.design.addFormPanel null, Template.projectForm, {doc: Projects.getCurrent()}
  'click .header .import.button': -> Template.design.addFormPanel null, Template.importForm
  'click .header .zoom.button': -> ProjectUtils.zoomToEntities()
