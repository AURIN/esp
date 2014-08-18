# The template is limited to a single instance, so we can store it and reference it in helper
# methods.
templateInstance = null
TemplateClass = Template.design

displayModesCollection = null
DisplayModes =
  footprint: 'Footprint'
  extrusion: 'Extrusion'
  mesh: 'Mesh'
Session.setDefault('displayMode', 'footprint')

collectionToForm =
  entities: 'entityForm'
  typologies: 'typologyForm'
  lots: 'lotForm'

TemplateClass.created = ->
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
  displayModesCollection = Collections.createTemporary()
  _.each DisplayModes, (name, id) ->
    displayModesCollection.insert({value: id, label: name})

TemplateClass.rendered = ->
  template = @
  atlasNode = @find('.atlas')

  # Don't show Atlas viewer if disabled.
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

  # Move extra buttons into collection tables
  $lotsTable = $(@find('.lots .collection-table'))
  $lotsButtons = $(@find('.lots .extra.menu')).addClass('item')
  $('.crud.menu', $lotsTable).after($lotsButtons)

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
      id = args.id
      collection = args.collection
      model = collection.findOne(id)
      collectionName = Collections.getName(collection)
      formName = collectionToForm[collectionName]
      console.debug 'onEdit', arguments, collectionName, formName
      TemplateClass.setUpFormPanel templateInstance, Template[formName], model
  displayModes: -> displayModesCollection.find()
  defaultDisplayMode: -> Session.get('displayMode')

TemplateClass.events
  'change .displayMode.dropdown': (e) ->
    displayMode = $(e.currentTarget).dropdown('get value')
    Session.set('displayMode', displayMode)

getSidebar = (template) ->
  $(template.find('.design.container > .sidebar'))

getEntityTable = (template) ->
  $(template.find('.entities .collection-table'))

getLotTable = (template) ->
  $(template.find('.lots .collection-table'))

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
  projectId = Projects.getCurrentId()
  AtlasManager.zoomToProject()

  # Rendering Lots.
  renderLot = (id) -> LotUtils.render(id)
  unrenderLot = (id) -> AtlasManager.unrenderEntity(id)
  lots = Lots.findForProject()
  entities = Entities.findForProject()
  # Listen to changes to Lots and (un)render them as needed.
  lots.observe
    added: (lot) ->
      renderLot(lot._id)
    changed: (newLot, oldLot) ->
      id = newLot._id
      unrenderLot(id)
      renderLot(id)
    removed: (lot) ->
      unrenderLot(lot._id)

  # Rendering Entities.
  renderEntity = (id) -> EntityUtils.render(id)
  unrenderEntity = (id) -> AtlasManager.unrenderEntity(id)
  # Listen to changes to Entities and Typologies and (un)render them as needed.
  entities.observe
    added: (entity) ->
      renderEntity(entity._id)
    changed: (newEntity, oldEntity) ->
      id = newEntity._id
      unrenderEntity(id)
      renderEntity(id)
    removed: (entity) ->
      unrenderEntity(entity._id)

  # Listen to selections from atlas.
  # TODO(aramk) Support multiple selection.
  # TODO(aramk) Remove duplication.
  $table = getLotTable(template)
  tableId = Template.collectionTable.getDomTableId($table)
  atlas.subscribe 'entity/select', (args) ->
    id = args.ids[0]
    Template.collectionTable.setSelectedId(tableId, id)
  atlas.subscribe 'entity/deselect', (args) ->
    Template.collectionTable.deselect(tableId)
  # Listen to selections in the table
  $table.on 'select', (e, id) ->
    atlas.publish('entity/select', ids: [id])
  $table.on 'deselect', (e, id) ->
    atlas.publish('entity/deselect', ids: [id])

  # Re-render when display mode changes.
  firstRun = true
  Deps.autorun (c) ->
    # Register a dependency on display mode changes.
    displayMode = Session.get('displayMode')
    if firstRun
      # Don't run the first time, since we already render through the observe() callback.
      firstRun = false
      return
    if projectId != Projects.getCurrentId()
      # Don't handle updates if changing project.
      c.stop()
      return
    console.log('displayMode', displayMode)
    _.each AtlasManager.getFeatures(), (entity) ->
      entity.setDisplayMode(displayMode);
