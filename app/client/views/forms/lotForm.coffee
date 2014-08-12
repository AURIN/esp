Meteor.startup ->

  EditState =
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

  currentFeature = null

  hasExisting = -> currentFeature?

  stopEditing = ->
    console.bug('stopping drawing')
    isCreating = getEditState(EditState.CREATING)
    isEditing = getEditState(EditState.EDITING)
    if isEditing
      console.debug('stopped editing');
      setEditState(EditState.EDITING, false)
    if isCreating
      console.debug('stopped creating');
      setEditState(EditState.CREATING, false)


  Form = Forms.defineModelForm
    name: 'lotForm'
    collection: 'Lots'
    onCreate: ->
      # TODO(aramk) Set these based on whether there is existing geometry or not?
      _.each _.values(EditState), (key) -> Session.set(key, false)
      @data ?= {}
      doc = @data.doc
      if doc
        id = doc._id
        AtlasManager.showEntity(id)
        currentFeature = AtlasManager.getEntity(id)
    onRender: ->
      $(@findAll('.ui.toggle.button')).state();

    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  isButtonActive = (node) -> $(node).hasClass('active')

  Form.events
    'click .footprint.buttons .create': (e, template) ->
      shouldCreate = isButtonActive(e.currentTarget)
      isCreating = getEditState(EditState.CREATING)
      if shouldCreate
        # TODO(aramk) Draw mode in atlas
        console.bug('enabled drawing')
        isCreating = setEditState(EditState.CREATING, shouldCreate)
      else if isCreating
        stopEditing()

    'click .footprint.buttons .edit': (e, template) ->
      shouldEdit = isButtonActive(e.currentTarget)
      isEditing = getEditState(EditState.EDITING) # setEditState(EditState.EDITING, isButtonActive(e.currentTarget))
      isCreated = getEditState(EditState.CREATED)
      if shouldEdit
        # TODO(aramk) Enable editing
        console.bug('enabled editing')
        isEditing = setEditState(EditState.EDITING, shouldEdit)
      else if isEditing
        stopEditing()

    'click .footprint.buttons .delete': (e, template) ->
      # TODO(aramk) Set the footprint being editing as the current footprint
      stopEditing()
      # TODO(aramk) Remove the footprint.
      setEditState(EditState.CREATING, false)
      setEditState(EditState.EDITING, false)
      setEditState(EditState.CREATED, false)

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
