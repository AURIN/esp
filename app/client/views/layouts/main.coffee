TemplateClass = Template.mainLayout

TemplateClass.rendered = ->

TemplateClass.helpers
  appName: -> AppConfig.name
  stateName: -> Session.get('stateName')
  project: -> Projects.getCurrent()
  helpUrl: -> AppConfig.helpUrl
  routeName: -> Router.getCurrentName()

TemplateClass.events
  'click .header .close.button': ->
    Router.go('projects')
  'click .header .edit.button': ->
    Template.design.addFormPanel null, Template.projectForm, {doc: Projects.getCurrent()}
  'click .header .import.button': -> Template.design.addFormPanel null, Template.importForm
  'click .header .export.button': -> EntityUtils.downloadInBrowser()
  'click .header .zoom.button': -> EntityUtils.zoomToEntities()
