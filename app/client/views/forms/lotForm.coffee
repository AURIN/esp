Meteor.startup ->

  EditState =
    CREATING: 'creating'
    EDITING: 'editing'
    CREATED: 'created'
    EDITED: 'edited'
    DELETED: 'deleted'

  # TODO(aramk) At the moment only one lot form instance can exist at once.
  getEditState = (name) -> Session.get('edit_' + name)
  setEditState = (name, value) ->
    Session.set('edit_' + name, value)
    value

  currentFeature = null

  hasExisting = -> currentFeature?

  observeStates = ->
    isCreated = getEditState(EditState.CREATED)
    isEdited = getEditState(EditState.EDITED)
    isDeleted = getEditState(EditState.DELETED)
    canCreate = (!(hasExisting() && !this.isFootprintDeleted) ||
      this.isCreatingFootprint) && !this.isFootprintCreated;

    canEdit = this.isEditingFootprint ||
      (this.hasExistingFootprint && !this.isFootprintDeleted) || this.isFootprintCreated;

    canDelete = (this.hasExistingFootprint && !this.isFootprintDeleted) ||
      this.isFootprintCreated || this.isFootprintDeleted;

  stopEditing = ->
    console.bug('stopped drawing')
    isCreating = getEditState(EditState.CREATING)
    isEditing = getEditState(EditState.EDITING)
    if isEditing
      # TODO(aramk) Stop editing
      setEditState(EditState.EDITING, false)
    if isCreating
      # TODO(aramk) Stop drawing
      setEditState(EditState.CREATING, false)


  Form = Forms.defineModelForm
    name: 'lotForm'
    collection: 'Lots'
    onCreate: ->
#      @data ?= {}
#      _.defaults(@data, {
#        isCreating: false
#        isEditing: false
#        # TODO(aramk) Set these based on whether there is existing geometry or not?
#        isCreated: false
#        isEdited: false
#        isDeleted: false
#      })
      # TODO(aramk) Set these based on whether there is existing geometry or not?
      _.each(
        _.values(EditState).concat(_.values(EditState))
        (key) -> Session.set(key, false)
      )
      @data ?= {}
      doc = @data.doc
      if doc
        id = doc._id
        AtlasManager.showEntity(id)
        currentFeature = AtlasManager.getEntity(id)
      observeStates()
    onRender: ->
      $(@findAll('.ui.toggle.button')).state();

    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  isButtonActive: (node) -> $(node).hasClass('active')

  Form.events
    'click .footprint.buttons .create': (e, template) ->
      isCreating = setEditState(EditState.CREATING, isButtonActive(e.currentTarget))
      setEditState(EditState.DELETED, false)
#      isCreated = getEditState(EditState.CREATED)
      if isCreating
        # TODO(aramk) Draw mode in atlas
        console.bug('enabled drawing')
#      else if isCreated
#        console.bug('removing drawing')
        # TODO(aramk) Remove existing
    'click .footprint.buttons .edit': (e, template) ->
      isEditing = setEditState(EditState.EDITING, isButtonActive(e.currentTarget))
      isCreated = getEditState(EditState.CREATED)
      isEdited = getEditState(EditState.EDITED)
      if isEditing
        # TODO(aramk) Enable editing
        console.bug('enabled editing')
      else
        stopEditing()
      if isCreated
        setEditState(EditState.EDITED, false)
      else
        setEditState(EditState.EDITED, isEdited || isEditing)
    'click .footprint.buttons .delete': (e, template) ->
#      isDeleted = isButtonActive(e.currentTarget)
      isDeleted = true
      isCreated = getEditState(EditState.CREATED)
      # TODO(aramk) Set this.
      stopEditing()
      if isDeleted
        if isCreated
          # TODO(aramk) Remove
          isDeleted = false
        else if hasExisting()
          # TODO(aramk) Hide

#      else
#        if isCreated
#          # TODO(aramk) Reset footprint
#        else if hasExisting
#          # TODO(aramk) show
      setEditState(EditState.DELETED, isDeleted)
      setEditState(EditState.CREATING, false)
      setEditState(EditState.EDITING, false)
      setEditState(EditState.CREATED, false)



  stateToActiveClass = (name) -> if getEditState(name) then 'active' else ''
  stateToDisabledClass = (name) -> if getEditState(name) then 'disabled' else ''

  Form.helpers
    classes: -> Typologies.toObjects()
    classValue: -> @doc?.parameters?.general?.class
#    isCreating: -> stateToActiveClass EditState.CREATING
#    isEditing: -> stateToActiveClass EditState.EDITING
#    isDeleted: -> stateToActiveClass EditState.DELETED
