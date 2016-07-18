####################################################################################################
# DESIGN PAGE
####################################################################################################

# The template is limited to a single instance, so we can store it and reference it in helper
# methods.
templateInstance = null
TemplateClass = Template.design

displayModesCollection = null
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
  layers: 'layerForm'
  lots:
    single: 'lotForm'
    multiple: 'lotBulkForm'

# Various handles which should be removed when the design template is removed
handles = null
# Handles for rendering due to collection changes.
renderHandles = null
# Handles for PubSub subscriptions.
pubsubHandles = null

# The current Blaze.View rendered in the left sidebar.
currentPanelView = null

TemplateClass.created = ->
  projectId = Projects.getCurrentId()
  project = Projects.getCurrent()
  unless project
    Logger.error('No project found', projectId)
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
  renderHandles = []
  pubsubHandles = []

TemplateClass.destroyed = ->
  _.each handles, (handle) -> handle.stop()
  _.each pubsubHandles, (handle) -> PubSub.unsubscribe(handle)
  unregisterCollectionRenderHandles()
  EntityUtils.beforeAtlasUnload()
  LotUtils.beforeAtlasUnload()
  LayerUtils.beforeAtlasUnload()
  AtlasManager.removeAtlas()
  # Remove any remaining popups.
  $('.ui.popup').remove()

TemplateClass.rendered = ->
  template = @
  atlasNode = @find('.atlas')
  currentPanelView = null

  # Don't show Atlas viewer if disabled.
  unless Window.getVarBool('atlas') == false
    requirejs [
      'atlas-cesium/core/CesiumAtlas'
      'atlas-cesium/cesium/Source/Widgets/BaseLayerPicker/ProviderViewModel'
      'atlas-cesium/cesium/Source/Scene/MapboxImageryProvider',
      'atlas/lib/utility/Log'
    ], (CesiumAtlas, ProviderViewModel, MapboxImageryProvider, Log) ->
      Logger.setLevel('error')
      Logger.debug('Creating Atlas...')
      cesiumAtlas = new CesiumAtlas
        managers:
          render:
            viewer:
              # Bing Maps imagery (the default) has recently broken.
              selectedImageryProviderViewModel: new ProviderViewModel
                name: 'MapBox',
                tooltip: 'MapBox',
                iconUrl: '',
                creationFunction: ->
                  new MapboxImageryProvider
                    mapId: 'mapbox.satellite'
      AtlasManager.setAtlas(cesiumAtlas)
      Logger.debug('Created Atlas', cesiumAtlas)
      Logger.debug('Attaching Atlas')
      cesiumAtlas.attachTo(atlasNode)
      cesiumAtlas.publish('debugMode', false)
      TemplateClass.onAtlasLoad(template, cesiumAtlas)

  # Move extra buttons into collection tables
  _.each ['lots', 'typologies', 'entities', 'layers'], (type) =>
    $table = $(@find('.' + type + ' .collection-table'))
    $buttons = $(@find('.' + type + ' .extra.menu')).addClass('item')
    $('.crud.menu', $table).after($buttons)

  # Remove create button for entities.
  $(@find('.entities .collection-table .create.item')).remove()
  # Remove create button for layers.
  $(@find('.layers .collection-table .create.item')).remove()

  # Use icons for display mode dropdowns
  selectors = ['.lotDisplayMode.dropdown', '.entityDisplayMode.dropdown',
      '.layerDisplayMode.dropdown']
  _.each selectors, (cls) ->
    $dropdown = @$(cls)
    $dropdown.addClass('item')
    $dropdown.attr('title', 'Toggle View Mode')
    $('.dropdown.icon', $dropdown).attr('class', 'photo icon')
    $('.text', $dropdown).hide()

  # Add popups to fields
  @$('[title]').popup()
  # Add toggle state for buttons.
  @$('.toggle').state()

  # Show a loader when rendering entities.
  @autorun ->
    entityCount = EntityUtils.getRenderCount()
    layerCount = LayerUtils.getRenderCount()
    setIsLoadingEntities(entityCount > 0 || layerCount > 0)

getSingleFormName = (formArgs) ->
  if Types.isString(formArgs.single) then formArgs.single else formArgs

onEditFormPanel = (args) ->
  ids = args.ids
  collection = args.collection
  collectionName = Collections.getName(collection)
  formArgs = collectionToForm[collectionName]
  formName = getSingleFormName(formArgs)
  if ids.length == 1
    isSingle = true
  else
    if Types.isString(formArgs.multiple)
      formName = formArgs.multiple
      docs = _.map ids, (id) -> collection.findOne(id)
      data = {lots: docs}
    else
      # Multiple are selected, but we only support single.
      isSingle = true
  if isSingle
    id = ids[0]
    data = {doc: collection.findOne(id)}
  Logger.debug 'onEdit', arguments, collectionName, formName
  TemplateClass.addFormPanel templateInstance, Template[formName], data

TemplateClass.helpers
  entities: -> Entities.findByProject()
  lots: -> Lots.findByProject()
  typologies: -> Typologies.findByProject()
  layers: -> Layers.findByProject()
  tableSettings: -> getTableSettings()
  layerTableSettings: ->
    settings = getTableSettings()
    settings.multiSelect = false
    settings.checkbox =
      # Unchecked state by default
      getValue: (layer) -> false
    settings
  displayModes: -> displayModesCollection.find(value: {$not: '_nonDevExtrusion'})
  lotDisplayModes: -> displayModesCollection.find(value: {$not: 'mesh'})
  layerDisplayModes: -> Layers.getDisplayModeItems()
  defaultEntityDisplayMode: -> Session.get('entityDisplayMode')
  defaultLotDisplayMode: -> Session.get('lotDisplayMode')

TemplateClass.events
  'change .entityDisplayMode.dropdown': (e) ->
    displayMode = Template.dropdown.getValue(e.currentTarget)
    Session.set('entityDisplayMode', displayMode)
  'click .entities .zoom.item': ->
    ids = Template.collectionTable.getSelectedIds(getEntityTable())
    AtlasManager.zoomToEntities(ids)
  'change .lotDisplayMode.dropdown': (e) ->
    displayMode = Template.dropdown.getValue(e.currentTarget)
    Session.set('lotDisplayMode', displayMode)
  'change .layerDisplayMode.dropdown': (e) ->
    displayMode = Template.dropdown.getValue(e.currentTarget)
    ids = Template.collectionTable.getSelectedIds(getLayerTable())
    _.each ids, (id) -> LayerUtils.setDisplayMode(id, displayMode)
  'click .allocate.item': (e, template) ->
    TemplateClass.addFormPanel(template, Template.autoAllocationForm)
  'click .filter.item': (e, template) ->
    TemplateClass.addFormPanel(template, Template.lotFilterForm)
  'mousedown .typologies .collection-table tr': (e) ->
    # Drag typology items from the table onto the globe.
    $pin = createDraggableTypology()
    $body = $('body')
    $body.addClass('dragging')
    $viewer = $('.viewer')
    typologyId = @_id
    margin = {left: -16, top: -38}
    sensitivity = 5

    getPinPos = (event) ->
      {left: event.clientX + margin.left, top: event.clientY + margin.top}
    origPinPos = getPinPos(e)

    mouseMoveHandler = (moveEvent) ->
      pos = getPinPos(event)
      hasMoved = Math.abs(pos.left - origPinPos.left) >= sensitivity ||
          Math.abs(pos.top - origPinPos.top) >= sensitivity
      $pin.toggle(hasMoved)
      $pin.offset(pos)
    
    isPositionInElement = ($em, position) ->
      emSize = $em.position()
      emSize.right = emSize.left + $em.width()
      emSize.bottom = emSize.top + $em.height()
      emSize.left <= position.left <= emSize.right &&
          emSize.top <= position.top <= emSize.bottom

    mouseUpHandler = (upEvent) ->
      $pin.remove()
      $body.off('mousemove', mouseMoveHandler)
      $body.off('mouseup', mouseUpHandler)
      $body.removeClass('dragging')

      return unless isPositionInElement($viewer, {left: upEvent.clientX, top: upEvent.clientY})

      viewerPos = $viewer.position()
      mousePos =
        x: upEvent.clientX - viewerPos.left,
        y: upEvent.clientY - viewerPos.top
      
      typology = Typologies.findOne(typologyId)
      typologyClass = SchemaUtils.getParameterValue(typology, 'general.class')
      if typologyClass == 'ASSET'
        AtlasManager.getAtlas().then (atlas) ->
          point = atlas.getManager('render').geoPointFromScreenCoord(mousePos)
          Entities.insert
            name: typology.name
            typology: typologyId
            project: Projects.getCurrentId()
            parameters:
              space:
                position:
                  latitude: point.latitude
                  longitude: point.longitude
      else
        entities = AtlasManager.getEntitiesAt(mousePos)
        if entities.length > 0
          lot = null
          _.some entities, (entity) ->
            feature = entity.getParent()
            lot = Lots.findOne(AtlasIdMap.getAppId(feature.getId()))
            lot
          if lot
            # TODO(aramk) Refactor with the logic in the lot form.
            if lot.entity
              Logger.error('Remove the existing entity before allocating a typology onto this lot.')
            else
              Lots.createEntity(lotId: lot._id, typologyId: typologyId)
    $body.mousemove(mouseMoveHandler)
    $body.mouseup(mouseUpHandler)
  'click .layers .import.item': ->
    Template.design.addFormPanel null, Template.importForm, {isLayer: true}
  'click .layers .zoom.item': (e, template) ->
    $table = getLayerTable(template)
    tableTemplate = Templates.getInstanceFromElement($table)
    ids = Template.collectionTable.getSelectedIds($table)
    dfs = _.map ids, (id) ->
      LayerUtils.render(id)
    Q.all(dfs).then -> AtlasManager.zoomToEntities(ids)
  'check .layers': (e, template, checkEvent) ->
    layerId = checkEvent.data._id
    isVisible = checkEvent.checked
    layer = AtlasManager.getEntity(layerId)
    if layer
      if isVisible then LayerUtils.show(layerId) else LayerUtils.hide(layerId)
    else if isVisible
      LayerUtils.render(layerId)

PubSub.subscribe 'typology/edit/form', (msg, typologyId) ->
  onEditFormPanel(ids: [typologyId], collection: Typologies)

PubSub.subscribe 'lot/edit/form', (msg, lotId) ->
  onEditFormPanel(ids: [lotId], collection: Lots)

createDraggableTypology = ->
  $pin = $('<div class="draggable-typology"></div>') # <i class="building icon"></i>
  $('body').append($pin)
  $pin.hide()

getSidebar = (template) ->
  $(template.find('.design.container > .sidebar'))

getEntityTable = (template) -> template.$('.entities .collection-table')
getTypologyTable = (template) -> template.$('.typologies .collection-table')
getLotTable = (template) -> template.$('.lots .collection-table')
getLayerTable = (template) -> getTemplate(template).$('.layers .collection-table')

getPathwayDrawButton = (template) -> template.$('.pathway.draw.button')

TemplateClass.addPanel = (template, panelTemplate, data) ->
  callback = -> TemplateClass.removePanel template
  data = Setter.merge({
    settings:
      onCancel: callback
      onSuccess: callback
  }, data)
  if currentPanelView
    TemplateClass.removePanel(template)
  $container = getSidebar(template)
  $panel = $('<div class="panel"></div>')
  $container.append $panel
  parentNode = $panel[0]
  if data
    currentPanelView = Blaze.renderWithData panelTemplate, data, parentNode
  else
    currentPanelView = Blaze.render panelTemplate, parentNode

TemplateClass.removePanel = (template) ->
  Logger.debug 'Removing panel', @, template
  # Parent node is kept so we need to remove it manually.
  $panel = $(Templates.getElement(currentPanelView))
  Blaze.remove(currentPanelView)
  $panel.remove()
  $container = getSidebar(template)
  $('>.panel:last', $container).show()
  currentPanelView = null

TemplateClass.addFormPanel = (template, formTemplate, data) ->
  template ?= templateInstance
  data ?= {}
  TemplateClass.addPanel template, formTemplate, data

getTableSettings = ->
  fields: [
    key: 'name'
    label: 'Name'
  ]
  onCreate: (args) ->
    collection = args.collection
    if collection == Entities
      throw new Error('Cannot directly create an entity - assign a Typology to a Lot.')
    collectionName = Collections.getName(collection)
    formArgs = collectionToForm[collectionName]
    formName = getSingleFormName(formArgs)
    Logger.debug 'onCreate', arguments, collectionName, formName
    TemplateClass.addFormPanel templateInstance, Template[formName]
  onEdit: onEditFormPanel

getTemplate = (template) -> Templates.getNamedInstance('design', template)

setIsLoadingEntities = (loading) ->
  $loader = getTemplate().$('.entities .loader')
  $loader.toggleClass('active', !!loading)

registerCollectionRenderHandles = (template) ->
  # Avoid registering handlers twice.
  return unless renderHandles.length == 0
  # Rendering Entities.

  ##################################################################################################
  # VISUALISATION MAINTENANCE
  ##################################################################################################

  hasParamChanged = (paramName, newDoc, oldDoc) ->
    newValue = SchemaUtils.getParameterValue(newDoc, paramName)
    oldValue = SchemaUtils.getParameterValue(oldDoc, paramName)
    newValue != oldValue

  hasRenderParamChanged = (newDoc, oldDoc) ->
    _.some [
      'general.class', 'space.geom_2d', 'space.geom_3d', 'space.height', 'orientation.azimuth',
      'composition.rd_lanes', 'composition.rd_width', 'composition.rd_mat',
      'composition.prk_lanes', 'composition.prk_width', 'composition.prk_mat',
      'composition.fp_lanes', 'composition.fp_width', 'composition.fp_mat',
      'composition.bp_lanes', 'composition.bp_width', 'composition.bp_mat',
      'composition.ve_lanes', 'composition.ve_width'
    ], (paramName) -> hasParamChanged(paramName, newDoc, oldDoc)

  # Rendering Lots.
  renderLot = (id) -> LotUtils.render(id)
  unrenderLot = (id) -> LotUtils.unrender(id)
  lots = Lots.findByProject()
  entities = Entities.findByProject()
  typologies = Typologies.findByProject()
  layers = Layers.findByProject()
  # Listen to changes to Lots and (un)render them as needed.
  renderHandles.push Collections.observe lots,
    added: (lot) ->
      renderLot(lot._id)
    changed: (newLot, oldLot) ->
      id = newLot._id
      oldEntityId = oldLot.entity
      newEntityId = newLot.entity
      lotChanged = _.some [
        'general.class', 'general.develop', 'space.geom_2d', 'space.height'
      ], (paramName) -> hasParamChanged(paramName, newLot, oldLot)
      lotChanged = lotChanged || newLot.entity != oldLot.entity
      if lotChanged
        unrenderLot(id)
        renderLot(id)
    removed: (lot) ->
      unrenderLot(lot._id)

  # Rendering Entities.
  renderEntity = (id) -> EntityUtils.render(id)
  unrenderEntity = (id) -> EntityUtils.unrender(id)
  refreshEntity = (id) ->
    unrenderEntity(id)
    renderEntity(id)
  # Listen to changes to Entities and Typologies and (un)render them as needed.
  renderHandles.push Collections.observe entities,
    added: (entity) ->
      renderEntity(entity._id)
    changed: (newEntity, oldEntity) ->
      id = newEntity._id
      if hasRenderParamChanged(newEntity, oldEntity) then refreshEntity(id)
    removed: (entity) ->
      unrenderEntity(entity._id)
  # Render existing Entities.
  _.each entities.fetch(), (entity) -> renderEntity(entity._id)

  # Re-render when display mode changes.
  reactiveToDisplayMode = (collection, cursor, sessionVarName, getDisplayMode) ->
    firstRun = true
    template.autorun (c) ->
      # Register a dependency on display mode changes.
      Session.get(sessionVarName)
      getDisplayMode ?= -> Session.get(sessionVarName)
      if firstRun
        # Don't run the first time, since we already render through the observe() callback.
        firstRun = false
        return
      ids = _.map cursor.fetch(), (doc) -> doc._id
      if collection.allowsMultipleDisplayModes?
        ids = _.filter ids, (id) -> collection.allowsMultipleDisplayModes(id)
      _.each AtlasManager.getEntitiesByIds(ids), (entity) ->
        entity.setDisplayMode(getDisplayMode(AtlasIdMap.getAppId(entity.getId())))

  reactiveToDisplayMode(Lots, Lots.findByProject(), 'lotDisplayMode', LotUtils.getDisplayMode)
  reactiveToDisplayMode(Entities, Entities.findByProject(), 'entityDisplayMode')

  # Re-render entities of a typology when fields affecting visualisation are changed.
  renderHandles.push Collections.observe typologies, {
    changed: (newTypology, oldTypology) ->
      if hasRenderParamChanged(newTypology, oldTypology)
        Entities.findByTypology(newTypology._id).forEach (entity) ->
          refreshEntity(entity._id)
  }

  # Rendering Layers.
  renderLayer = (id) -> LayerUtils.render(id)
  unrenderLayer = (id) -> LayerUtils.unrender(id)
  refreshLayer = (id) ->
    unrenderLayer(id)
    renderLayer(id)
  renderHandles.push Collections.observe layers,
    added: (layer) ->
      renderLayer(layer._id)
    changed: (newLayer, oldLayer) ->
      hasChanged = _.some [
        'general.displayMode', 'space.geom_2d', 'space.geom_3d', 'space.height'
      ], (paramName) -> hasParamChanged(paramName, newLayer, oldLayer)
      if hasChanged then refreshLayer(newLayer._id)
    removed: (layer) ->
      unrenderLayer(layer._id)
  # Render existing Entities.
  _.each layers.fetch(), (layer) -> renderLayer(layer._id)

unregisterCollectionRenderHandles = (template) ->
  _.each renderHandles, (handle) -> handle.stop()
  renderHandles = []

TemplateClass.onAtlasLoad = (template, atlas) ->
  df = Q.defer()
  unregisterCollectionRenderHandles(template, atlas)
  Q.all([LotUtils.renderAllAndZoom(), EntityUtils.renderAll()]).fin ->
    bindEntityEvents(template, atlas)
    df.resolve()
  df.promise

bindEntityEvents = (template, atlas) ->
  registerCollectionRenderHandles(template)
  return if template.entitiesEventsBound
  template.entitiesEventsBound = true

  $entityTable = getEntityTable(template)
  $typologyTable = getTypologyTable(template)
  $lotTable = getLotTable(template)
  $layerTable = getLayerTable(template)

  # Topics for disabling reactive rendering.
  pubsubHandles.push PubSub.subscribe 'entities/reactive-render', (msg, enabled) ->
    if enabled
      registerCollectionRenderHandles(template, atlas)
    else
      unregisterCollectionRenderHandles(template, atlas)

  # Topic for reloading design contents.
  pubsubHandles.push PubSub.subscribe 'project/reload', (msg, callback) ->
    currentProjectId = Projects.getCurrentId()
    Router.go('projects')
    _.delay(
      -> Router.go('design', {_id: currentProjectId})
      1000
    )

  pubsubHandles.push PubSub.subscribe 'entities/reload', (msg, callback) ->
    TemplateClass.onAtlasLoad(template, atlas).fin(callback)

  ##################################################################################################
  # SELECTION
  ##################################################################################################

  # Determine what table should be used for the given doc type.
  getTable = (docId) ->
    if Entities.findOne(docId)
      $entityTable
    else if Lots.findOne(docId)
      $lotTable

  # Listen to selections in tables.
  tables = [$entityTable, $lotTable]
  # Prevent bulk selections of entities when selecting the typology table from needlessly triggering
  # the table event handlers below or causing infinite loops.
  tableSelectionEnabled = true
  _.each tables, ($table) ->
    $table.on 'select', (e, args) ->
      return unless tableSelectionEnabled
      selectedIds = args.added
      deselectedIds = args.removed
      AtlasManager.selectEntities(selectedIds)
      AtlasManager.deselectEntities(deselectedIds)
  
  # Clicking on a typology selects all entities of that typology.
  getEntityIdsByTypologyId = (typologyId) ->
    _.pluck Entities.findByTypology(typologyId).fetch(), '_id'
  $typologyTable.on 'select', (e, args) ->
    tableSelectionEnabled = false
    selectedId = args.added[0]
    deselectedId = args.removed[0]
    if deselectedId
      AtlasManager.deselectEntities(getEntityIdsByTypologyId(deselectedId))
    if selectedId
      AtlasManager.selectEntities(getEntityIdsByTypologyId(selectedId))
      # Hide all popups so they don't obsruct the entities.
      _.each atlas._managers.popup.getPopups(), (popup) -> popup.hide()
    tableSelectionEnabled = true
  
  # Select the item in the table when clicking on the globe.
  atlas.subscribe 'entity/select', (args) ->
    tableSelectionEnabled = false
    ids = _.map args.ids, (id) -> AtlasManager.resolveModelId(id)
    $table = getTable(ids[0])
    Template.collectionTable.addSelection($table, ids) if $table
    tableSelectionEnabled = true
  atlas.subscribe 'entity/deselect', (args) ->
    tableSelectionEnabled = false
    ids = _.map args.ids, (id) -> AtlasManager.resolveModelId(id)
    $table = getTable(ids[0])
    Template.collectionTable.removeSelection($table, ids) if $table
    tableSelectionEnabled = true

  # Listen to double clicks from Atlas.
  atlas.subscribe 'entity/dblclick', (args) ->
    id = AtlasManager.resolveModelId(args.id)
    collections = [Entities, Lots]
    collection = _.find collections, (collection) -> collection.findOne(id) && collection
    # Ignore this event when clicking on entities we don't manage in collections.
    return unless collection
    doc = collection.findOne(id)
    return unless doc
    # When clicking on an allocated Open Space lot, open the entity form instead.
    if collection == Lots && doc.entity? &&
        Entities.getTypologyClass(doc.entity) == 'OPEN_SPACE'
      id = doc.entity
      collection = Entities
    onEditFormPanel(ids: [id], collection: collection)
    # If double clicking a pathway, switch to edit mode.
    if collection == Entities && Entities.getTypologyClass(id) == 'PATHWAY'
      editGeoEntity(id)

  # Check the checkboxes when rendering into layers.
  pubsubHandles.push PubSub.subscribe 'layer/show', (msg, id) ->
    tableTemplate = Templates.getInstanceFromElement(getLayerTable(template))
    $row = Template.collectionTable.getRow(id, tableTemplate)
    $('[type="checkbox"]', $row).prop('checked', true)

  # Selecting Open Space lots should select the entity, if any.
  atlas.subscribe 'entity/select', (args) ->
    ids = _.map args.ids, (id) -> AtlasManager.resolveModelId(id)
    _.each ids, (id) ->
      lot = Lots.findOne(id)
      return unless lot?.entity? && Entities.getTypologyClass(lot.entity) == 'OPEN_SPACE'
      # $table = getTable(id)
      # Template.collectionTable.addSelection($table, [id]) if $table
      EntityUtils.render(lot.entity).then (geoEntity) -> geoEntity.setSelected(true)

  # Selecting/deselecting entities in the table should select the lot on the globe.
  $entityTable.on 'select', (e, args) ->
    toSelectIds = []
    _.each args.added, (id) ->
      entity = Entities.findOne(id)
      return unless entity
      lotId = entity.lot
      if lotId? then toSelectIds.push(lotId)
    AtlasManager.selectEntities(toSelectIds)
    toDeselectIds = []
    _.each args.removed, (id) ->
      entity = Entities.findOne(id)
      return unless entity
      lotId = entity.lot
      if lotId? then toDeselectIds.push(lotId)
    AtlasManager.deselectEntities(toDeselectIds)

  ##################################################################################################
  # DRAWING
  ##################################################################################################

  # Selecting typologies in the table shows and hides the draw button for pathways.
  $pathwayDrawButton = getPathwayDrawButton(template)
  
  getSelectedTypology = ->
    selectedIds = Template.collectionTable.getSelectedIds($typologyTable)
    return null if selectedIds.length < 1
    Typologies.findOne(selectedIds[0])

  getSelectedPathwayTypology = ->
    typology = getSelectedTypology()
    return null unless typology?
    typologyClass = Typologies.getTypologyClass(typology._id)
    if typologyClass == 'PATHWAY' then typology else null

  onTypologySelectionChange = ->
    selectedIds = Template.collectionTable.getSelectedIds($typologyTable)
    # Currently only a single pathway can be selected for drawing.
    typology = getSelectedPathwayTypology()
    $pathwayDrawButton.toggle(typology?)

  $typologyTable.on 'select deselect', onTypologySelectionChange
  onTypologySelectionChange()

  stopDrawing = -> atlas.publish('entity/draw/stop')

  $pathwayDrawButton.on 'click', ->
    isActive = $pathwayDrawButton.hasClass('active')
    startDrawing = ->
      stopDrawing()
      atlas.publish 'entity/draw', {
        displayMode: 'line'
        init: (args) -> args.feature.setElevation(2)
        create: (args) ->
          typology = getSelectedPathwayTypology()
          subclass = SchemaUtils.getParameterValue(typology, 'general.subclass')
          # TODO(aramk) Generate an incremented name.
          name = subclass
          feature = args.feature
          vertices = feature.getForm().getVertices()
          feature.remove()
          if vertices.length > 2 || (vertices.length == 2 && !vertices[0].equals(vertices[1]))
            WKT.polylineFromVertices vertices, (wktStr) ->
              Entities.insert
                name: name
                typology: typology._id
                project: Projects.getCurrentId()
                parameters:
                  space:
                    geom_2d: wktStr
          # Continue drawing if the button is active.
          isActive = $pathwayDrawButton.hasClass('active')
          startDrawing() if isActive
        update: (args) -> args.feature.getHandles().forEach (handle) -> handle.setElevation(4)
        cancel: (args) ->
          Logger.debug('Drawing cancelled', arguments)
          args.feature.remove()
          $pathwayDrawButton.removeClass('active')
      }
    if isActive
      startDrawing()
    else
      atlas.publish('entity/draw/stop', {validate: false})

  editGeoEntity = (id) ->
    atlas.publish('edit/disable')
    atlas.publish('edit/enable', {
      ids: [id]
      complete: ->
        feature = AtlasManager.getEntity(id)
        WKT.featureToWkt feature, (wktStr) ->
          Entities.update id, {$set: {'parameters.space.geom_2d': wktStr}}, (err, result) ->
            refreshEntity(id)
      cancel: -> refreshEntity(id)
    })

  ##################################################################################################
  # AMALGAMATION & SUBDIVISION
  ##################################################################################################

  # Bind atlas event to show/hide the amalgamation button and handle the click event.

  firstSelectedLotId = null
  $amalgamateButton = template.$('.amalgamate.item').hide()
  $amalgamateButton.click ->
    ids = LotUtils.getSelectedLots()
    LotUtils.amalgamate(ids)
  $subdivideButton = template.$('.subdivide.item').hide()
  $subdivideButton.click ->
    ids = LotUtils.getSelectedLots()
    
    startDrawing = ->
      stopDrawing()
      # Ensure lots are displayed as footprints.
      Session.set('lotDisplayMode', 'footprint')
      atlas.publish 'entity/draw', {
        displayMode: 'line'
        init: (args) -> args.feature.setElevation(2)
        create: (args) ->
          feature = args.feature
          vertices = feature.getForm().getVertices()
          feature.remove()
          LotUtils.subdivide(ids, vertices).fin(cancelSubdivision)
        update: (args) -> args.feature.getHandles().forEach (handle) -> handle.setElevation(4)
        cancel: (args) ->
          Logger.debug('Drawing cancelled', arguments)
          args.feature.remove()
          cancelSubdivision()
          $subdivideButton.removeClass('active')
      }

    isActive = $subdivideButton.hasClass('active')
    if isActive
      if ids.length == 0
        throw new Error('Select at least one Lot to subdivide.')
      startDrawing()
    else
      atlas.publish('entity/draw/stop', {validate: false})

  cancelSubdivision = -> $subdivideButton.removeClass('active')

  ##################################################################################################
  # AUTO-ALIGNMENT
  ##################################################################################################

  $alignmentButton = template.$('.alignment.item').hide()
  $alignmentButton.click ->
    ids = LotUtils.getSelectedLots()
    LotUtils.autoAlign(ids)

  atlas.subscribe 'entity/select', (args) ->
    id = args.ids[0]
    lot = Lots.findOne(id)
    return unless lot
    geoEntity = AtlasManager.getEntity(id)
    geoEntity

  ##################################################################################################
  # LOT-SELECTION
  ##################################################################################################

  $allocationButton = template.$('.allocate.item').hide()

  # Hide and show buttons based on the selected Lots.
  atlas.subscribe 'entity/selection/change', (args) ->
    ids = LotUtils.getSelectedLots()
    idCount = ids.length
    if idCount == 0
      firstSelectedLotId = null
    else if idCount == 1
      firstSelectedLotId = ids[0]
    $amalgamateButton.toggle(idCount > 1)
    $subdivideButton.toggle(idCount > 0)
    $alignmentButton.toggle(idCount > 0)
    $allocationButton.toggle(idCount > 0)

  ##################################################################################################
  # SELECTION BASED BUTTONS
  ##################################################################################################

  $entityZoomButton = template.$('.entities .zoom.item').hide()
  $layerZoomButton = template.$('.layers .zoom.item').hide()

  _.each [
    {element: $entityTable, templateClass: Template.collectionTable, buttons: [$entityZoomButton]}
    {element: $layerTable, templateClass: Template.collectionTable, buttons: [$layerZoomButton]}
  ], (item) ->
    $element = item.element
    $element.on 'select', (args) ->
      ids = item.templateClass.getSelectedIds($element)
      _.each item.buttons, ($button) -> $button.toggle(ids.length > 0)

  ##################################################################################################
  # LAYERS
  ##################################################################################################

  $layerDisplayModeButton = template.$('.layers .layerDisplayMode').hide()
  $layerTable.on 'select', (args) ->
    ids = Template.collectionTable.getSelectedIds($layerTable)
    $layerDisplayModeButton.toggle(ids.length > 0)
    layer = Layers.findOne(ids[0])
    return unless layer
    displayMode = LayerUtils.getDisplayMode(layer._id)
    Template.dropdown.setValue($layerDisplayModeButton, displayMode)
  LayerUtils.setUpDisplayMode()

