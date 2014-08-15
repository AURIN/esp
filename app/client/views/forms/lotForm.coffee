Meteor.startup ->

  EditState =
    CHANGED: 'changed'
    CREATED: 'created'
#    EDITED: 'edited'
#    DELETED: 'deleted'
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

  Form = Forms.defineModelForm
    name: 'lotForm'
    collection: 'Lots'
    onCreate: ->
      # TODO(aramk) Set these based on whether there is existing geometry or not?
      _.each _.values(EditState), (key) -> setEditState(key, false)
      @data ?= {}
      doc = @data.doc
      if doc
        id = doc._id
        AtlasManager.showEntity(id)
        currentGeoEntity = AtlasManager.getEntity(id)
        if currentGeoEntity?
          setEditState(EditState.CREATED, true)
          currentGeoEntity.onSelect()

    onRender: -> $(@findAll('.ui.toggle.button')).state()

    onSuccess: (operation, result, template) ->
      data = template.data
      id = if operation == 'insert' then result else data.doc._id
      doc = Lots.findOne(id)
      settings = data.settings || {}
      callback = settings.onSuccess
      entityDf = Q.defer()
      geomDf = Q.defer()

      # Handle drawing and editing.
      stopEditing()
      stopCreating()
      unless currentGeoEntity?
        console.error('No geometry provided for lot.')
        return
      WKT.fromVertices currentGeoEntity.getVertices(), (wkt) ->
        console.log('wkt', wkt)
        geomDf.resolve(wkt)

      # Handle saving entity.
      oldEntityId = doc?.entity
      oldTypologyId = getTypologyId(doc)
      newTypologyId = $(template.find('.typology.dropdown')).dropdown('get value')
      newTypology = Typologies.findOne(newTypologyId)
      classParamId = 'parameters.general.class'
      geomParamId = 'parameters.space.geom'
      if oldTypologyId != newTypologyId
        # If no class is provided, use that of the entity's typology.
        lotClass = Lots.getParameter(doc, classParamId)
        unless lotClass
          lotClass = Typologies.getParameter(newTypology, classParamId)

        # Create a new entity for this lot-typology combination and remove the existing one
        # (if any). Name of the entity matches that of the lot.
        newEntity =
          name: doc.name
          typology: newTypologyId
          project: Projects.getCurrentId()
        Entities.insert newEntity, (err, newEntityId) ->
          resolve = -> entityDf.resolve(newEntityId)
          reject = (err) ->
            console.error.apply(console, arguments)
            entityDf.reject(err)
          if err
            reject('Updating entity of lot failed', err)
          else
            if oldEntityId?
              Entities.remove oldEntityId, (err, result) ->
                if err
                  reject('Removing old entity failed', err)
                else
                  resolve()
            else
              resolve()
      else
        entityDf.resolve(oldEntityId)
      Q.all([entityDf, geomDf]).then (entityId, wkt) ->
        modifier = {entity: entityId}
        if lotClass?
          modifier[classParamId] = lotClass
        modifier[geomParamId] = wkt
        Lots.update id, {$set: modifier}, (err, result) ->
          if err
            console.error('Updating lot failed', err)
          else
            callback(result) if callback

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
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  isButtonActive = (node) -> $(node).hasClass('active')

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
      AtlasManager.unrenderEntity(currentGeoEntity.getId())
      setEditState(EditState.CREATING, false)
      setEditState(EditState.EDITING, false)
      setEditState(EditState.CREATED, false)
      setEditState(EditState.CHANGED, true)

  stateToActiveClass = (name) -> if getEditState(name) then 'active' else ''
  boolToEnabledClass = (bool) -> if bool then '' else 'disabled'

  Form.helpers
    classes: -> Typologies.classes
    typologies: -> Typologies.find()
    typology: -> getTypologyId(@doc)
    classValue: -> @doc?.parameters?.general?.class
    isCreating: -> stateToActiveClass(EditState.CREATING)
    isEditing: -> stateToActiveClass(EditState.EDITING)
    canCreate: -> boolToEnabledClass(!getEditState(EditState.CREATED))
    canEdit: -> boolToEnabledClass(getEditState(EditState.CREATED))
    canDelete: -> boolToEnabledClass(getEditState(EditState.CREATED))
