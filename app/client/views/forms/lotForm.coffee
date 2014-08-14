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
    onRender: ->
      $(@findAll('.ui.toggle.button')).state();

    onSuccess: (operation, result, template) ->
      stopEditing()
      stopCreating()
      settings = template.data.settings || {}
      callback = settings.onSuccess
      doc = template.data.doc
      id = if operation == 'insert' then result else doc._id
      WKT.fromVertices currentGeoEntity.getVertices(), (wkt) ->
        console.log('wkt', wkt)
        Lots.update id, {$set: {'parameters.space.geom': wkt}}
        callback(id) if callback

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
    classes: -> Typologies.toObjects()
    classValue: -> @doc?.parameters?.general?.class
    isCreating: -> stateToActiveClass(EditState.CREATING)
    isEditing: -> stateToActiveClass(EditState.EDITING)
    canCreate: -> boolToEnabledClass(!getEditState(EditState.CREATED))
    canEdit: -> boolToEnabledClass(getEditState(EditState.CREATED))
    canDelete: -> boolToEnabledClass(getEditState(EditState.CREATED))
