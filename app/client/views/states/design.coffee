# The template is limited to a single instance, so we can store it and reference it in helper
# methods.
templateInstance = null
TemplateClass = Template.design

collectionToForm =
  entities: 'entityForm'
  typologies: 'typologyForm'
  lots: 'lotForm'

TemplateClass.created = ->
  console.log('TemplateClass')
  #  projectId = Session.get('projectId')
  #  console.log('projects', Projects.find().fetch())
  #  Projects.setCurrentId(projectId)
  projectId = Projects.getCurrentId()
  project = Projects.getCurrent()
  unless project
    console.error('No project found', projectId);
    Router.go('projects')
  else
    Deps.autorun ->
      project = Projects.findOne(projectId)
      Session.set('stateName', project.name)
  templateInstance = @

TemplateClass.rendered = ->
  # TODO(aramk) Data is what is passed to the template, not the data on the instance.
  @data ?= {}

  template = @
  atlasNode = @find('.atlas')

  # Don't show Atlas viewer.
  unless Window.getVarBool('atlas') == false
    require([
        'atlas-cesium/core/CesiumAtlas',
        'atlas/lib/utility/Log'
      ], (CesiumAtlas, Log) =>
      Log.setLevel('debug')
      console.debug('Creating Atlas...')
      cesiumAtlas = new CesiumAtlas()
      AtlasManager.setInstance(cesiumAtlas)
      console.debug('Created Atlas', cesiumAtlas)
      console.debug('Attaching Atlas')
      cesiumAtlas.attachTo(atlasNode)
      cesiumAtlas.publish('debugMode', true)
      TemplateClass.onAtlasLoad(template, cesiumAtlas)
    )

TemplateClass.helpers
  entities: -> Entities.find({project: Projects.getCurrentId()})
  lots: -> Lots.find({project: Projects.getCurrentId()})
  typologies: -> Typologies.find({project: Projects.getCurrentId()})
  tableSettings: ->
    fields: [
      key: 'name'
      label: 'Name'
    ]
    rowsPerPage: 100000
    showNavigation: 'never'
    onCreate: (args) ->
      collectionName = Collections.getName(args.collection)
      formName = collectionToForm[collectionName]
      console.debug 'onCreate', arguments, collectionName, formName
      TemplateClass.setUpFormPanel templateInstance, Template[formName]
    onEdit: (args) ->
      collectionName = Collections.getName(args.collection)
      formName = collectionToForm[collectionName]
      console.debug 'onEdit', arguments, collectionName, formName
      TemplateClass.setUpFormPanel templateInstance, Template[formName], args.model

getSidebar = (template) ->
  $(template.find('.design.container > .sidebar'))

TemplateClass.addPanel = (template, component) ->
  console.debug 'addPanel', template, component
  $container = getSidebar(template)
  $panel = $('<div class="panel"></div>')
  $('>.panel', $container).hide();
  $container.append $panel
  UI.insert component, $panel[0]

TemplateClass.removePanel = (template, component) ->
  console.debug 'Removing panel', @, template, component
  TemplateUtils.getDom(component).remove()
  $container = getSidebar(template)
  $('>.panel:last', $container).show()

TemplateClass.setUpPanel = (template, panelTemplate, data) ->
  panel = UI.renderWithData panelTemplate, data
  TemplateClass.addPanel template, panel
  panel

TemplateClass.setUpFormPanel = (template, formTemplate, doc, settings) ->
  template ?= templateInstance
  settings ?= {}
  data =
    doc: doc, settings: settings
  panel = TemplateClass.setUpPanel template, formTemplate, data
  callback = -> TemplateClass.removePanel template, panel
  settings.onCancel = settings.onSuccess = callback
  panel

TemplateClass.onAtlasLoad = (template, atlas) ->
  # Zoom to project location
  projectId = Projects.getCurrentId()
  location = Projects.getLocationCoords(projectId)
  if location.latitude? and location.longitude?
    location.elevation ?= 20000
    console.debug 'Loading project location', location
    atlas.publish 'camera/zoomTo', {position: location}
  else
    address = Projects.getLocationAddress(projectId)
    console.debug 'Loading project address', address
    atlas.publish 'camera/zoomTo', {address: address}

  # Render lots
  lots = Lots.findForProject(projectId).fetch()
  _.each lots, (lot) ->
    LotUtils.toGeoEntityArgs(lot._id).then (geoEntityArgs) ->
      console.log('geoEntityArgs', lot, geoEntityArgs)
      atlas.publish 'entity/show', geoEntityArgs

