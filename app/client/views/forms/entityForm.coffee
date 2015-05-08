Meteor.startup ->

  collection = Entities

  getTypologyInput = ->
    $(@.find('[name="typology"]')).closest('.dropdown')

  getSelectOption = (value, $select) ->
    $('option[value="' + value + '"]', $select)

  updateFields = ->
    doc = @data.doc
    # Used to store original copies of DOM nodes which we modify based on the typology class.
    origInputs = @origInputs
    unless @origInputs
      origInputs = @origInputs = {}
    # TODO(aramk) Refactor with typeForm.
    typologyId = doc?.typology ? Template.dropdown.getValue(getTypologyInput.call(@))
    typology = Typologies.findOne(typologyId)
    typologyClass = SchemaUtils.getParameterValue(typology, 'general.class')
    subclass = SchemaUtils.getParameterValue(typology, 'general.subclass')
    defaultParams = Typologies.getDefaultParameterValues(typologyClass, subclass)
    #    defaultParams = Typologies.mergeDefaults(typology ? {})
    console.debug 'updateFields', @, arguments, typologyId, typology, typologyClass
    for key, input of Form.getSchemaInputs(@)
      fieldSchema = input.field
      isParamField = ParamUtils.hasPrefix(key)
      paramName = ParamUtils.removePrefix(key) if isParamField
      classes = fieldSchema.classes
      classOptions = classes?[typologyClass]
      allClassOptions = classes?.ALL
      if classOptions != false && allClassOptions?
        classOptions = _.extend(allClassOptions, classOptions)
      isHiddenField = classes and not classOptions

      $input = $(input.node)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      # Hide fields which have classes specified which don't contain the current class.
      $wrapper[if isHiddenField then 'hide' else 'show']()

      # For entities, we need to distinguish between default values inherited by the typology and
      # typology values that will be inherited by the entity.
      typologyValue = null
      if typology && isParamField
        typologyValue = SchemaUtils.getParameterValue(typology, paramName)
      if isParamField
        defaultValue = SchemaUtils.getParameterValue(defaultParams, key)
      else
        # Regular field - not a parameter.
        defaultValue = fieldSchema.defaultValue

      if typologyValue?
        # Add placeholders for inherited values
        $input.attr('placeholder', typologyValue)
      else if defaultValue?
        # Add placeholders for default values
        $input.attr('placeholder', defaultValue)

      unless isParamField
        continue

      entity = @data.doc
      entityValue = SchemaUtils.getParameterValue(entity, paramName) if entity

      # For a dropdown field, show the inherited or default value with labels.
      if $input.is('select')
        origInput = origInputs[key]
        if origInput
          # This field has been modified before - replace with a clone of the original.
          $origInput = origInputs[key].clone()
          $input.replaceWith($origInput)
          $origInput.val($input.val())
          $input = $origInput
        else
          # The field is in its original state - store a clone.
          origInputs[key] = $input.clone()

        if typologyValue?
          $inheritedOption = getSelectOption(typologyValue, $input)
          if $inheritedOption.length > 0
            $inheritedOption.text($inheritedOption.text() + ' (Inherited)')
        if defaultValue?
          # Label which option is the default value.
          $defaultOption = getSelectOption(defaultValue, $input)
          if $defaultOption.length > 0
            $defaultOption.text($defaultOption.text() + ' (Default)')
        # Only show None if we don't have a set or inherited value
        if !entityValue? && !typologyValue? && !defaultValue?
          # TODO(aramk) This is not available if a value or default value exists, since we cannot
          # override with null yet.
          $option = $('<option value="">None</option>')
          $input.prepend($option)
          Forms.setInputValue($input, '')
      
      # For all non-input fields (e.g. checkboxes), set the value of the entity field. Input
      # checkboxes use placeholders instead to allow inheriting values from the typology.
      if !entityValue? && !$input.is('input')
        Forms.setInputValue($input, typologyValue)
        if typologyValue?
          Forms.setInputValue($input, typologyValue)
        else if defaultValue?
          Forms.setInputValue($input, defaultValue)

  Form = Forms.defineModelForm
    name: 'entityForm'
    collection: collection
    onRender: ->
      updateFields.call(@)
      $typologyInput = getTypologyInput.call(@)
      $typologyInput.on 'change', => updateFields.call(@)
      # Select only the entity currently being edited (if any) so it's clear to the user.
      doc = @data.doc
      if doc
        toSelect = [doc._id]
        # If editing an Open Space Entity, select the Lot so it can be seen.
        if doc.lot? && Entities.getTypologyClass(doc._id) == 'OPEN_SPACE'
          toSelect.push(doc.lot)
        AtlasManager.setSelection(toSelect)
    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc
      before:
        update: (docId, modifier, template) ->
          # Prevent the lack of space fields from causing them to be removed.
          delete modifier.$unset?['parameters.space']
          # Disable editing to ensure changes are saved before re-rendering removes them.
          AtlasManager.getAtlas().then (atlas) =>
            atlas.publish('edit/disable')
            @result(modifier)
          # Ensure this hook is asynchronous
          return undefined

  Form.helpers
    typologies: -> Typologies.findByProject()
    typologyName: -> Typologies.findOne(@doc?.typology)?.name ? 'None'
    lotName: -> Lots.findOne(@doc?.lot)?.name

  Form.events
    'click .typology.button': (e, template) ->
      typologyId = template.data.doc?.typology
      return unless typologyId
      PubSub.publish('typology/edit/form', typologyId)
    'click .lot.button': (e, template) ->
      lotId = template.data.doc?.lot
      return unless lotId
      PubSub.publish('lot/edit/form', lotId)
