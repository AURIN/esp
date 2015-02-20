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
  lots:
    single: 'lotForm'
    multiple: 'lotBulkForm'

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
  EntityUtils.beforeAtlasUnload()
  LotUtils.beforeAtlasUnload()
  AtlasManager.removeAtlas()

TemplateClass.rendered = ->
  template = @
  atlasNode = @find('.atlas')
  currentPanelView = null

  # Don't show Atlas viewer if disabled.
  unless Window.getVarBool('atlas') == false
    require [
      'atlas-cesium/core/CesiumAtlas',
      'atlas/lib/utility/Log'
    ], (CesiumAtlas, Log) ->
      Log.setLevel('error')
      console.debug('Creating Atlas...')
      cesiumAtlas = new CesiumAtlas()
      AtlasManager.setAtlas(cesiumAtlas)
      console.debug('Created Atlas', cesiumAtlas)
      console.debug('Attaching Atlas')
      cesiumAtlas.attachTo(atlasNode)
      cesiumAtlas.publish('debugMode', false)
      TemplateClass.onAtlasLoad(template, cesiumAtlas)

  # Move extra buttons into collection tables
  _.each ['lots', 'typologies', 'entities'], (type) =>
    $table = $(@find('.' + type + ' .collection-table'))
    $buttons = $(@find('.' + type + ' .extra.menu')).addClass('item')
    $('.crud.menu', $table).after($buttons)

  # Remove create button for entities.
  $(@find('.entities .collection-table .create.item')).remove()

  # Add popups to fields
  @$('.has-popup').popup()
  # Add toggle state for buttons.
  @$('.toggle').state()

  # Use icons for display mode dropdowns
  _.each ['.lotDisplayMode.dropdown', '.entityDisplayMode.dropdown'], (cls) ->
    $dropdown = @$(cls)
    $dropdown.addClass('item')
    $('.dropdown.icon', $dropdown).attr('class', 'photo icon')
    $('.text', $dropdown).hide()

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
      data = {docs: docs}
    else
      # Multiple are selected, but we only support single.
      isSingle = true
  if isSingle
    id = ids[0]
    data = {doc: collection.findOne(id)}
  console.debug 'onEdit', arguments, collectionName, formName
  TemplateClass.addFormPanel templateInstance, Template[formName], data

TemplateClass.helpers
  entities: -> Entities.findByProject()
  lots: -> Lots.findByProject()
  typologies: -> Typologies.findByProject()
  tableSettings: ->
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
    mouseMoveHandler = (moveEvent) ->
      margin = {left: -16, top: -38}
      $pin.offset(left: moveEvent.clientX + margin.left, top: moveEvent.clientY + margin.top)
    mouseUpHandler = (upEvent) ->
      viewerPos = $viewer.position()
      entities = AtlasManager.getEntitiesAt({
        x: upEvent.clientX - viewerPos.left,
        y: upEvent.clientY - viewerPos.top
      })
      if entities.length > 0
        lot = null
        _.some entities, (entity) ->
          feature = entity.getParent()
          lot = Lots.findOne(feature.getId())
          lot
        if lot
          # TODO(aramk) Refactor with the logic in the lot form.
          if lot.entity
            console.error('Remove the existing entity before allocating a typology onto this lot.')
          else
            Lots.createEntity(lotId: lot._id, typologyId: typologyId)
          # TODO(aramk) Add to lot
      # If the typology was dragged on the globe, allocate it to any available lots.
      $pin.remove()
      $body.off('mousemove', mouseMoveHandler)
      $body.off('mouseup', mouseUpHandler)
      $body.removeClass('dragging')
    $body.mousemove(mouseMoveHandler)
    $body.mouseup(mouseUpHandler)

PubSub.subscribe 'typology/edit/form', (msg, typologyId) ->
  onEditFormPanel(ids: [typologyId], collection: Typologies)

createDraggableTypology = ->
  $pin = $('<div class="draggable-typology"></div>') # <i class="building icon"></i>
  $('body').append($pin)
  $pin

getSidebar = (template) ->
  $(template.find('.design.container > .sidebar'))

getEntityTable = (template) -> template.$('.entities .collection-table')
getTypologyTable = (template) -> template.$('.typologies .collection-table')
getLotTable = (template) -> template.$('.lots .collection-table')

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
  console.debug 'Removing panel', @, template
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

TemplateClass.onAtlasLoad = (template, atlas) ->
  projectId = Projects.getCurrentId()

  ##################################################################################################
  # VISUALISATION MAINTENANCE
  ##################################################################################################

  # Rendering Lots.
  renderLot = (id) -> LotUtils.render(id)
  unrenderLot = (id) -> LotUtils.unrender(id)
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

  ProjectUtils.zoomToEntities()

  # Rendering Entities.
  renderEntity = (id) -> EntityUtils.render(id)
  unrenderEntity = (id) -> EntityUtils.unrender(id)
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
        entity.setDisplayMode(getDisplayMode(entity.getId()))

  reactiveToDisplayMode(Lots, Lots.findByProject(), 'lotDisplayMode', LotUtils.getDisplayMode)
  reactiveToDisplayMode(Entities, Entities.findByProject(), 'entityDisplayMode')

  # Re-render entities of a typology when fields affecting visualisation are changed.
  handles.push Collections.observe typologies, {
    changed: (newTypology, oldTypology) ->
      hasParamChanged = (paramName) ->
        newValue = SchemaUtils.getParameterValue(newTypology, paramName)
        oldValue = SchemaUtils.getParameterValue(oldTypology, paramName)
        newValue != oldValue
      hasChanged = _.some([
          'general.class', 'space.geom_2d', 'space.geom_3d', 'space.height', 'orientation.azimuth',
          'composition.rd_lanes', 'composition.rd_width', 'composition.rd_mat',
          'composition.prk_lanes', 'composition.prk_width', 'composition.prk_mat',
          'composition.fp_lanes', 'composition.fp_width', 'composition.fp_mat',
          'composition.bp_lanes', 'composition.bp_width', 'composition.bp_mat',
          'composition.ve_lanes', 'composition.ve_width'
        ]
        (paramName) -> hasParamChanged(paramName)
      )
      if hasChanged
        _.each Entities.findByTypology(newTypology._id).fetch(), (entity) ->
          refreshEntity(entity._id)
  }

  ##################################################################################################
  # SELECTION
  ##################################################################################################

  # Determine what table should be used for the given doc type.
  getTable = (docId) ->
    if Entities.findOne(docId)
      getEntityTable(template)
    else if Lots.findOne(docId)
      getLotTable(template)

  # Listen to selections in tables.
  tables = [getEntityTable(template), getLotTable(template)]
# Prevent bulk selections of entities when selecting the typology table from needlessly triggering
  # the table event handlers below or causing infinite loops.
  tableSelectionEnabled = true
  _.each tables, ($table) ->
    $table.on 'select', (e, args) ->
      return unless tableSelectionEnabled
      selectedIds = args.added
      deselectedIds = args.removed
      atlas.publish('entity/select', ids: selectedIds) && selectedIds
      atlas.publish('entity/deselect', ids: deselectedIds) && deselectedIdsq
  
  # Clicking on a typology selects all entities of that typology.
  $typologyTable = getTypologyTable(template)
  getEntityIdsByTypologyId = (typologyId) ->
    _.map Entities.findByTypology(typologyId).fetch(), (entity) -> entity._id
  $typologyTable.on 'select', (e, args) ->
    tableSelectionEnabled = false
    selectedId = args.added[0]
    deselectedId = args.removed[0]
    if deselectedId
      atlas.publish('entity/deselect', ids: getEntityIdsByTypologyId(deselectedId))
    if selectedId
      atlas.publish('entity/select', ids: getEntityIdsByTypologyId(selectedId))
      # Hide all popups so they don't obsruct the entities.
      _.each atlas._managers.popup.getPopups(), (popup) -> popup.hide()
    tableSelectionEnabled = true
  
  # Select the item in the table when clicking on the globe.
  atlas.subscribe 'entity/select', (args) ->
    tableSelectionEnabled = false
    ids = _.map args.ids, (id) -> resolveModelId(id)
    $table = getTable(ids[0])
    Template.collectionTable.addSelection($table, ids) if $table
    tableSelectionEnabled = true
  atlas.subscribe 'entity/deselect', (args) ->
    tableSelectionEnabled = false
    ids = _.map args.ids, (id) -> resolveModelId(id)
    $table = getTable(ids[0])
    Template.collectionTable.removeSelection($table, ids) if $table
    tableSelectionEnabled = true

  # Listen to double clicks from Atlas.
  atlas.subscribe 'entity/dblclick', (args) ->
    id = resolveModelId(args.id)
    collections = [Entities, Lots]
    collection = _.find collections, (collection) -> collection.findOne(id) && collection
    # Ignore this event when clicking on entities we don't manage in collections.
    return unless collection
    entity = collection.findOne(id)
    return unless entity
    onEditFormPanel(ids: [id], collection: collection)
    # If double clicking a pathway, switch to edit mode.
    if collection == Entities && Entities.getTypologyClass(id) == 'PATHWAY'
      editGeoEntity(id)

  resolveModelId = (id) ->
    # When clicking on children of a GeoEntity collection, take the prefix as the ID of the
    # underlying Entity.
    reChildEntityId = /(^[^:]+):[^:]+$/
    idParts = id.match(reChildEntityId)
    if idParts
      id = idParts[1]
    id

  ##################################################################################################
  # DRAWING
  ##################################################################################################

  # Selecting typologies in the table shows and hides the draw button for pathways.
  $typologyTable = getTypologyTable(template)
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
          id = feature.getId()
          vertices = feature.getForm().getVertices()
          AtlasManager.unrenderEntity(id)
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
          console.debug('Drawing cancelled', arguments)
          feature = args.feature
          id = feature.getId()
          AtlasManager.unrenderEntity(id)
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
    ids = AtlasManager.getSelectedLots()
    LotUtils.amalgamate(ids)
  $subdivideButton = template.$('.subdivide.item').hide()
  $subdivideButton.click ->
    ids = AtlasManager.getSelectedLots()
    
    startDrawing = ->
      stopDrawing()
      # Ensure lots are displayed as footprints.
      Session.set('lotDisplayMode', 'footprint')
      atlas.publish 'entity/draw', {
        displayMode: 'line'
        init: (args) -> args.feature.setElevation(2)
        create: (args) ->
          feature = args.feature
          id = feature.getId()
          vertices = feature.getForm().getVertices()
          AtlasManager.unrenderEntity(id)
          LotUtils.subdivide(ids, vertices).fin(cancelSubdivision)
        update: (args) -> args.feature.getHandles().forEach (handle) -> handle.setElevation(4)
        cancel: (args) ->
          console.debug('Drawing cancelled', arguments)
          feature = args.feature
          id = feature.getId()
          AtlasManager.unrenderEntity(id)
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
    ids = AtlasManager.getSelectedLots()
    LotUtils.autoAlign(ids)

  atlas.subscribe 'entity/select', (args) ->
    id = args.ids[0]
    lot = Lots.findOne(id)
    return unless lot
    geoEntity = AtlasManager.getEntity(id)
    geoEntity

  # Auto-align when adding new lots or adding/replacing entities on lots.

  autoAlignEntity = (entity) ->
    azimuth = SchemaUtils.getParameterValue(entity, 'orientation.azimuth')
    LotUtils.autoAlign([entity.lot]) unless azimuth?

  Collections.observe Lots.findByProject(),
    added: (newDoc) ->
      entityId = newDoc.entity
      if entityId
        autoAlignEntity(Entities.findOne(entityId))
    changed: (newDoc, oldDoc) ->
      entityId = newDoc.entity
      if entityId && oldDoc.entity != entityId
        autoAlignEntity(Entities.findOne(entityId))

  ##################################################################################################
  # LOT-SELECTION
  ##################################################################################################

  $allocationButton = template.$('.allocate.item').hide()

  # Hide and show buttons based on the selected Lots.
  atlas.subscribe 'entity/selection/change', (args) ->
    ids = AtlasManager.getSelectedLots()
    idCount = ids.length
    if idCount == 0
      firstSelectedLotId = null
    else if idCount == 1
      firstSelectedLotId = ids[0]
    $amalgamateButton.toggle(idCount > 1)
    $subdivideButton.toggle(idCount > 0)
    $alignmentButton.toggle(idCount > 0)
    $allocationButton.toggle(idCount > 0)

