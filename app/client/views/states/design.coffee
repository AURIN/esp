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

# Various handles which should be removed when the design template is removed
handles = null

# The current Blaze.View rendered in the left sidebar.
currentPanelView = null

TemplateClass.created = ->
  projectId = Projects.getCurrentId()
  project = Projects.getCurrent()
  unless project
    console.error('No project found', projectId)
    Router.go('projects')
  else
    @autorun ->
      project = Projects.findOne(projectId)
      Session.set('stateName', project.name)
  templateInstance = @
  displayModesCollection = Collections.createTemporary()
  _.each DisplayModes, (name, id) ->
    displayModesCollection.insert({value: id, label: name})
  handles = []

TemplateClass.destroyed = ->
  _.each handles, (handle) -> handle.stop()

TemplateClass.rendered = ->
  template = @
  atlasNode = @find('.atlas')
  currentPanelView = null

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
    $table = $(@find('.' + type + ' .collection-table'))
    $buttons = $(@find('.' + type + ' .extra.menu')).addClass('item')
    $('.crud.menu', $table).after($buttons)

  # Remove create button for entities.
  $(@find('.entities .collection-table .create.item')).remove()

  # Add popups to fields
  @$('.popup').popup()

  # Use icons for display mode dropdowns
  _.each ['.lotDisplayMode.dropdown', '.entityDisplayMode.dropdown'], (cls) ->
    $dropdown = @$(cls)
    $('.dropdown.icon', $dropdown).attr('class', 'photo icon')
    $('.text', $dropdown).hide()

# TODO(aramk) Use a callback for when each row is created in the collection table.
#  @autorun ->
#    Typologies.findByProject()
#

onEditFormPanel = (args) ->
  id = args.ids[0]
  collection = args.collection
  model = collection.findOne(id)
  collectionName = Collections.getName(collection)
  formName = collectionToForm[collectionName]
  console.debug 'onEdit', arguments, collectionName, formName
  TemplateClass.addFormPanel templateInstance, Template[formName], model

TemplateClass.helpers
  entities: -> Entities.findByProject()
  lots: -> Lots.findByProject()
  typologies: -> Typologies.findByProject()
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
      TemplateClass.addFormPanel templateInstance, Template[formName]
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
  'mousedown .typologies .collection-table tr': (e) ->
    # Drag typology items from the table onto the globe.
    console.log('mousedown')
    $row = $(e.currentTarget)
    $pin = createDraggableTypology()
    #    $row.data('pin', $pin)
    $body = $('body')
    handles = []
    handles.push $body.mousemove (moveEvent) ->
#      $pin.left(moveEvent.clientX)
#      $pin.top(moveEvent.clientY)
      $pin.offset(left: moveEvent.clientX, top: moveEvent.clientY)
    handles.push $body.mouseup (upEvent) ->
      entity = AtlasManager.getEntitiesAt(x: upEvent.clientX, y:upEvent.clientY)[0]
      if entity
        console.log('entity', entity)
        lot = Lots.findOne(entity.getId())
        if lot
          # TODO(aramk) Refactor with the logic in the lot form.
          if lot.entity
            replaceExisting = confirm('This Lot already has an Entity - do you want to replace it?')
            # TODO(aramk) Reuse logic, or add it in collection hooks.
#            if replaceExisting
#              Typologies.
          console.log('allocating', lot)

          # TODO(aramk) Add to lot
      # If the typology was dragged on the globe, allocate it to any available lots.
      console.log('mouseup')
      #      $pin = $row.data('pin')
      #      unless $pin
      #        _.each handles, (handle) -> handle.cancel()
      #      return
      console.log('handles', handles)
      console.log('pin', $pin)
      $pin.remove()

createDraggableTypology = ->
  $pin = $('<div class="draggable-typology"><i class="building icon"></i></div>')
  $('body').append($pin)
  $pin

getSidebar = (template) ->
  $(template.find('.design.container > .sidebar'))

getEntityTable = (template) -> $(template.find('.entities .collection-table'))
getTypologyTable = (template) -> $(template.find('.typologies .collection-table'))
getLotTable = (template) -> $(template.find('.lots .collection-table'))

TemplateClass.addPanel = (template, panelTemplate, data) ->
  if currentPanelView
    TemplateClass.removePanel(template)
  $container = getSidebar(template)
  $panel = $('<div class="panel"></div>')
  #  $('>.panel', $container).hide()
  $container.append $panel
  parentNode = $panel[0]
  if data
    currentPanelView = Blaze.renderWithData panelTemplate, data, parentNode
  else
    currentPanelView = Blaze.render panelTemplate, parentNode

TemplateClass.removePanel = (template) ->
  console.debug 'Removing panel', @, template
  # Parent node is kept so we need to remove it manually.
  $panel = $(TemplateUtils.getDom(currentPanelView))
  Blaze.remove(currentPanelView)
  $panel.remove()
  $container = getSidebar(template)
  $('>.panel:last', $container).show()
  currentPanelView = null

TemplateClass.addFormPanel = (template, formTemplate, doc, settings) ->
  template ?= templateInstance
  settings ?= {}
  data =
    doc: doc, settings: settings
  TemplateClass.addPanel template, formTemplate, data
  callback = -> TemplateClass.removePanel template
  settings.onCancel = settings.onSuccess = callback

TemplateClass.onAtlasLoad = (template, atlas) ->
  projectId = Projects.getCurrentId()

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
  handles.push Collections.observe lots,
    added: (lot) ->
      renderLot(lot._id)
    changed: (newLot, oldLot) ->
      id = newLot._id
      oldEntityId = oldLot.entity
      newEntityId = newLot.entity
      unrenderLot(id)
      renderLot(id).then ->
        unrenderEntity(oldEntityId)
        if newEntityId?
          renderEntity(newEntityId)
    removed: (lot) ->
      unrenderLot(lot._id)

  LotUtils.renderAllAndZoom()

  # Rendering Entities.
  renderEntity = (id) -> EntityUtils.render(id)
  unrenderEntity = (id) -> AtlasManager.unrenderEntity(id)
  refreshEntity = (id) ->
    unrenderEntity(id)
    renderEntity(id)
  # Listen to changes to Entities and Typologies and (un)render them as needed.
  handles.push Collections.observe entities,
    added: (entity) ->
      renderEntity(entity._id)
    changed: (newEntity, oldEntity) ->
      id = newEntity._id
      refreshEntity(id)
    removed: (entity) ->
      unrenderEntity(entity._id)
  # Render existing Entities.
  _.each entities.fetch(), (entity) -> renderEntity(entity._id)

  # Re-render when display mode changes.
  reactiveToDisplayMode = (collection, sessionVarName, getDisplayMode) ->
    firstRun = true
    template.autorun (c) ->
      # Register a dependency on display mode changes.
      Session.get(sessionVarName)
      getDisplayMode ?= -> Session.get(sessionVarName)
      if firstRun
        # Don't run the first time, since we already render through the observe() callback.
        firstRun = false
        return
      ids = _.map collection.find().fetch(), (doc) -> doc._id
      _.each AtlasManager.getEntitiesByIds(ids), (entity) ->
        entity.setDisplayMode(getDisplayMode(entity.getId()))

  reactiveToDisplayMode(Lots, 'lotDisplayMode', LotUtils.getDisplayMode)
  reactiveToDisplayMode(Entities, 'entityDisplayMode')

  # Re-render entities of a typology when fields affecting visualisation are changed.
  handles.push Collections.observe typologies, {
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
