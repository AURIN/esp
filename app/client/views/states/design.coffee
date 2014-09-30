# The template is limited to a single instance, so we can store it and reference it in helper
# methods.
templateInstance = null
TemplateClass = Template.design

displayModesCollection = null
#_nonDevExtrusionModeId = '_nonDevExtrusion'
@DisplayModes =
  footprint: 'Footprint'
  extrusion: 'Extrusion'
  mesh: 'Mesh'
  _nonDevExtrusion: 'Extrude Non-Develop'
Session.setDefault('lotDisplayMode', 'footprint')
Session.setDefault('entityDisplayMode', 'extrusion')

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
    @autorun ->
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
      AtlasManager.setAtlas(cesiumAtlas)
      console.debug('Created Atlas', cesiumAtlas)
      console.debug('Attaching Atlas')
      cesiumAtlas.attachTo(atlasNode)
      cesiumAtlas.publish('debugMode', false)
      TemplateClass.onAtlasLoad(template, cesiumAtlas)
    )

  # Move extra buttons into collection tables
  _.each ['lots', 'entities'], (type) =>
    $lotsTable = $(@find('.' + type + ' .collection-table'))
    $lotsButtons = $(@find('.' + type + ' .extra.menu')).addClass('item')
    $('.crud.menu', $lotsTable).after($lotsButtons)

  # Remove create button for entities.
  $(@find('.entities .collection-table .create.item')).remove();

onEditFormPanel = (args) ->
  id = args.ids[0]
  collection = args.collection
  model = collection.findOne(id)
  collectionName = Collections.getName(collection)
  formName = collectionToForm[collectionName]
  console.debug 'onEdit', arguments, collectionName, formName
  TemplateClass.setUpFormPanel templateInstance, Template[formName], model

TemplateClass.helpers
  entities: -> Entities.find({project: Projects.getCurrentId()})
  lots: -> Lots.find({project: Projects.getCurrentId()})
  typologies: -> Typologies.find({project: Projects.getCurrentId()})
  tableSettings: ->
    fields: [
      key: 'name'
      label: 'Name'
    ]
#    rowsPerPage: 100000
#    showNavigation: 'never'
    onCreate: (args) ->
      collection = args.collection
      if collection == Entities
        throw new Error('Cannot directly create an entity - assign a Typology to a Lot.')
      collectionName = Collections.getName(collection)
      formName = collectionToForm[collectionName]
      console.debug 'onCreate', arguments, collectionName, formName
      TemplateClass.setUpFormPanel templateInstance, Template[formName]
    onEdit: onEditFormPanel
  displayModes: -> displayModesCollection.find(value: {$not: '_nonDevExtrusion'})
  lotDisplayModes: -> displayModesCollection.find(value: {$not: 'mesh'})
  defaultEntityDisplayMode: -> Session.get('entityDisplayMode')
  defaultLotDisplayMode: -> Session.get('lotDisplayMode')

TemplateClass.events
  'change .entityDisplayMode.dropdown': (e) ->
    displayMode = Template.dropdown.getValue(e.currentTarget)
    Session.set('entityDisplayMode', displayMode)
  'change .lotDisplayMode.dropdown': (e) ->
    displayMode = Template.dropdown.getValue(e.currentTarget)
    Session.set('lotDisplayMode', displayMode)
  'click .allocate.item': (e) ->
    LotUtils.autoAllocate()

getSidebar = (template) ->
  $(template.find('.design.container > .sidebar'))

getEntityTable = (template) -> $(template.find('.entities .collection-table'))
getTypologyTable = (template) -> $(template.find('.typologies .collection-table'))
getLotTable = (template) -> $(template.find('.lots .collection-table'))

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

  ##################################################################################################
  # VISUALISATION MAINTENANCE
  ##################################################################################################

  # Rendering Lots.
  renderLot = (id) -> LotUtils.render(id)
  unrenderLot = (id) -> AtlasManager.unrenderEntity(id)
  lots = Lots.findByProject()
  entities = Entities.findByProject()
  typologies = Typologies.findByProject()
  # Listen to changes to Lots and (un)render them as needed.
  Collections.observe lots,
    added: (lot) ->
      renderLot(lot._id)
    changed: (newLot, oldLot) ->
      id = newLot._id
      oldEntityId = oldLot.entity
      newEntityId = newLot.entity
      unrenderLot(id)
      renderLot(id)
      unrenderEntity(oldEntityId)
      if newEntityId?
        renderEntity(newEntityId)
    removed: (lot) ->
      unrenderLot(lot._id)
  # Render existing Lots.
  _.each lots.fetch(), (lot) -> renderLot(lot._id)

  # Rendering Entities.
  renderEntity = (id) -> EntityUtils.render(id)
  unrenderEntity = (id) -> AtlasManager.unrenderEntity(id)
  refreshEntity = (id) ->
    unrenderEntity(id)
    renderEntity(id)
  # Listen to changes to Entities and Typologies and (un)render them as needed.
  Collections.observe entities,
    added: (entity) ->
      renderEntity(entity._id)
    changed: (newEntity, oldEntity) ->
      id = newEntity._id
      refreshEntity(id)
    removed: (entity) ->
      unrenderEntity(entity._id)
  # Render existing Entities.
  _.each entities.fetch(), (entity) -> renderEntity(entity._id)

  # If entities exist, zoom into them.
  if entities.length == 0
    AtlasManager.zoomToProjectEntities()

  # Re-render when display mode changes.
  reactiveToDisplayMode = (collection, sessionVarName, getDisplayMode) ->
    firstRun = true
    Deps.autorun (c) ->
      # Register a dependency on display mode changes.
      Session.get(sessionVarName)
      getDisplayMode ?= -> Session.get('entityDisplayMode')
      if firstRun
        # Don't run the first time, since we already render through the observe() callback.
        firstRun = false
        return
      if projectId != Projects.getCurrentId()
        # Don't handle updates if changing project.
        c.stop()
        return
      ids = _.map collection.find().fetch(), (doc) -> doc._id
      _.each AtlasManager.getEntitiesByIds(ids), (entity) ->
        entity.setDisplayMode(getDisplayMode(entity.getId()));

  reactiveToDisplayMode(Lots, 'lotDisplayMode', LotUtils.getDisplayMode)
  reactiveToDisplayMode(Entities, 'entityDisplayMode')

  # Re-render entities of a typology when fields affecting visualisation are changed.
  Collections.observe typologies, {
    changed: (newTypology, oldTypology) ->
      hasParamChanged = (paramName) ->
        newValue = Typologies.getParameter(newTypology, paramName)
        oldValue = Typologies.getParameter(oldTypology, paramName)
        newValue != oldValue
      hasChanged = _.some ['general.class', 'space.geom_2d', 'space.geom_3d', 'space.height',
                           'orientation.azimuth'], (paramName) -> hasParamChanged(paramName)
      if hasChanged
        _.each Entities.find(typology: newTypology._id).fetch(), (entity) ->
          refreshEntity(entity._id)
  }

  # Listen to selections from Atlas.

  # Listen to selections in tables.
  tables = [getEntityTable(template), getLotTable(template)]
  _.each tables, ($table) ->
    $table.on 'select', (e, id) -> atlas.publish('entity/select', ids: [id])
    $table.on 'deselect', (e, id) -> atlas.publish('entity/deselect', ids: [id])
  # Clicking on a typology selects all entities of that typology.
  $typologyTable = getTypologyTable(template)
  getEntityIdsByTypologyId = (typologyId) ->
    _.map Entities.find(typology: typologyId).fetch(), (entity) -> entity._id
  $typologyTable.on 'select', (e, id) ->
    atlas.publish('entity/select', ids: getEntityIdsByTypologyId(id))
  $typologyTable.on 'deselect', (e, id) ->
    atlas.publish('entity/deselect', ids: getEntityIdsByTypologyId(id))

  # Determine what table should be used for the given doc type.
  getTable = (docId) ->
    if Entities.findOne(docId)
      getEntityTable(template)
    else if Lots.findOne(docId)
      getLotTable(template)

  # Select the item in the table when clicking on the globe.
  atlas.subscribe 'entity/select', (args) ->
    # Always deselect the typologies table to avoid its logic from interfering.
    typologyTableId = Template.collectionTable.getDomTableId(getTypologyTable(template))
    Template.collectionTable.deselectAll(typologyTableId)

    id = args.ids[0]
    tableId = Template.collectionTable.getDomTableId(getTable(id))
    Template.collectionTable.addSelection(tableId, id) if tableId
  atlas.subscribe 'entity/deselect', (args) ->
    id = args.ids[0]
    if id
      tableId = Template.collectionTable.getDomTableId(getTable(id))
      Template.collectionTable.removeSelection(tableId, id) if tableId

  # Listen to double clicks from Atlas.
  atlas.subscribe 'entity/dblclick', (args) ->
    collection = Entities
    id = args.id
    unless collection.findOne(id)
      collection = Lots
    unless collection.findOne(id)
      throw new Error('Cannot find model with ID ' + id + ' in a collection.')
    onEditFormPanel ids: [id], collection: collection
