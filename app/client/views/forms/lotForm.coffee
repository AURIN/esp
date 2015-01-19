Meteor.startup ->

  formName = 'lotForm'
  collection = Lots

  EditState =
    CHANGED: 'changed'
    CREATED: 'created'
    CREATING: 'creating'
    EDITING: 'editing'

  # TODO(aramk) At the moment only one lot form instance can exist at once.
  getEditState = (name) -> Session.get('edit_' + name)
  setEditState = (name, value) ->
    Session.set('edit_' + name, value)
    value

  # A reference to the current Atlas GeoEntity.
  currentGeoEntity = null

  stopEditing = ->
    isEditing = getEditState(EditState.EDITING)
    if isEditing
      AtlasManager.stopEdit()
      setEditState(EditState.EDITING, false)

  stopCreating = ->
    isCreating = getEditState(EditState.CREATING)
    if isCreating
      AtlasManager.stopDraw()
      setEditState(EditState.CREATING, false)

  getTypologyId = (doc) ->
    entityId = doc?.entity
    unless entityId?
      return null
    Entities.findOne(entityId)?.typology ? null

  getTypologyDropdown = (template) -> $(template.find('.typology.dropdown'))

  addTypologiesForClass = (typologyClass, template) ->
    typologies = template.typologies
    Collections.removeAllDocs(typologies)
    Typologies.findByClass(typologyClass).forEach (typology) -> typologies.insert(typology)

  Form = Forms.defineModelForm
    name: formName
    collection: collection
    onCreate: ->
      # TODO(aramk) Set these based on whether there is existing geometry or not?
      _.each _.values(EditState), (key) -> setEditState(key, false)
      data = @data ?= {}
      doc = @data.doc
      @typologies = Collections.createTemporary()
      if doc
        id = doc._id
        AtlasManager.showEntity(id)
        currentGeoEntity = AtlasManager.getEntity(id)
        if currentGeoEntity?
          setEditState(EditState.CREATED, true)
          AtlasManager.setSelection([id])
        entityId = doc.entity
        if entityId
          addTypologiesForClass(Entities.getTypologyClass(entityId), @)
      Session.set('_forDev', if doc then SchemaUtils.getParameterValue(doc, 'general.develop') else true)

    onRender: -> $(@findAll('.ui.toggle.button')).state()

    onSuccess: (operation, result, template) ->
      # Create the entity from the typology if none exists, or replace it if the typology class was
      # changed.
      data = template.data
      id = if operation == 'insert' then result else data.doc._id
      doc = Lots.findOne(id)
      entityDf = Q.defer()
      
      # If not for development, there is no dropdown.
      $typologyDropdown = getTypologyDropdown(template)
      newTypologyId = Template.dropdown.getValue($typologyDropdown)
      if newTypologyId
        Lots.createEntity(lotId: id, typologyId: newTypologyId, allowReplace: true)
            .then(entityDf.resolve, entityDf.reject)
      else
        entityDf.resolve(null)
      
      # Remove the drawn/edited Lot if it's temporary.
      if currentGeoEntity? && !Lots.findOne(currentGeoEntity.getId())
        currentGeoEntity.remove()
      
      entityDf.promise

    onCancel: (template) ->
      stopEditing()
      stopCreating()
      isChanged = getEditState(EditState.CHANGED)
      unless isChanged
        return
      # Remove the existing GeoEntity, whether it was drawn or edited.
      if currentGeoEntity
        currentGeoEntity.remove()
      doc = template.data.doc
      id = doc?._id
      LotUtils.render(id) if id

    hooks:
      before:
        insert: (doc, template) ->
          setTypologyValue(doc, true, template).then =>
            console.log('setTypologyValue', arguments)
            @result(doc)
          return undefined
        update: (docId, modifier, template) ->
          setTypologyValue(modifier, false, template).then =>
            console.log('setTypologyValue', arguments)
            @result(modifier)
          return undefined
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  isButtonActive = (node) -> $(node).hasClass('active')

  # Without this method, changing the class doesn't unset the typology in the document.
  setTypologyValue = (doc, isInserting, template) ->
    # If not for development, there is no dropdown.
    $typologyDropdown = getTypologyDropdown(template)
    newTypologyId = null
    if $typologyDropdown.length > 0
      newTypologyId = Template.dropdown.getValue($typologyDropdown)
    unless newTypologyId
      if isInserting
        doc.entity = undefined
      else
        doc.$unset ?= {}
        doc.$unset.entity = null
    setGeometry(doc, isInserting, template)

  setGeometry = (doc, isInserting, template) ->
    geomDf = Q.defer()
    # Handle drawing and editing.
    stopEditing()
    stopCreating()
    unless currentGeoEntity?
      console.error('No geometry provided for lot.')
      return
    isChanged = getEditState(EditState.CHANGED)
    if isChanged
      WKT.polygonFromVertices currentGeoEntity.getVertices(), (wkt) ->
        modifier = {$set: {'parameters.space.geom_2d': wkt}}
        if isInserting
          Setter.merge(doc, Collections.simulateModifierUpdate(doc, modifier))
        else
          Setter.merge(doc, modifier)
          delete doc.$unset?['parameters.space']
          delete doc.$unset?['parameters.space.geom_2d']
        geomDf.resolve()
    else
      geomDf.resolve()

    geomDf.promise

  Form.events
    'click .footprint.buttons .create': (e, template) ->
      shouldCreate = isButtonActive(e.currentTarget)
      isCreating = getEditState(EditState.CREATING)
      setEditState(EditState.CHANGED, true)
      if shouldCreate
        isCreating = setEditState(EditState.CREATING, true)
        AtlasManager.draw
          create: (args) ->
            currentGeoEntity = args.feature
            setEditState(EditState.CREATED, true)
            setEditState(EditState.CREATING, false)
      else if isCreating
        stopCreating()

    'click .footprint.buttons .edit': (e, template) ->
      shouldEdit = isButtonActive(e.currentTarget)
      isEditing = getEditState(EditState.EDITING)
      setEditState(EditState.CHANGED, true)
      if shouldEdit
        isEditing = setEditState(EditState.EDITING, true)
        AtlasManager.edit
          ids: [currentGeoEntity.getId()]
          complete: (args) ->
            setEditState(EditState.CREATED, true)
            setEditState(EditState.EDITING, false)
      else if isEditing
        stopEditing()

    'click .footprint.buttons .delete': (e, template) ->
      stopEditing()
      stopCreating()
      LotUtils.unrender(currentGeoEntity.getId())
      setEditState(EditState.CREATING, false)
      setEditState(EditState.EDITING, false)
      setEditState(EditState.CREATED, false)
      setEditState(EditState.CHANGED, true)

    'change [name="parameters.general.develop"]': (e, template) ->
      shouldEdit = $(e.currentTarget).is(':checked')
      Session.set('_forDev', shouldEdit)

    'change [name="parameters.general.class"]': (e, template) ->
      value = Template.dropdown.getValue($(e.target).closest('.dropdown'))
      addTypologiesForClass(value, template)

  stateToActiveClass = (name) -> if getEditState(name) then 'active' else ''
  boolToEnabledClass = (bool) -> if bool then '' else 'disabled'
  getTemplate = (template) -> Templates.getNamedInstance(formName, template)

  # TODO(aramk) Abstract dropdown to allow null selection automatically.
  Form.helpers
    classes: -> Collections.createTemporary(Typologies.getAllocatableClassItems())
    typologyId: -> getTypologyId(@doc)
    typologies: -> getTemplate().typologies
    forDev: -> Session.get('_forDev')
    isCreating: -> stateToActiveClass(EditState.CREATING)
    isEditing: -> stateToActiveClass(EditState.EDITING)
    canCreate: -> boolToEnabledClass(!getEditState(EditState.CREATED))
    canEdit: -> boolToEnabledClass(getEditState(EditState.CREATED))
    canDelete: -> boolToEnabledClass(getEditState(EditState.CREATED))
