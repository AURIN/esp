Meteor.startup ->

  collection = Entities

  getTypologyInput = ->
    $(@.find('[name="typology"]')).closest('.dropdown')

  getSelectOption = (value, $select) ->
    $('option[value="' + value + '"]', $select)

  updateFields = ->
    # Used to store original copies of DOM nodes which we modify based on the typology class.
    origInputs = @origInputs
    unless @origInputs
      origInputs = @origInputs = {}
    # TODO(aramk) Refactor with typeForm.
    typologyId = Template.dropdown.getValue(getTypologyInput.call(@))
    typology = Typologies.findOne(typologyId)
    typologyClass = typology?.parameters?.general?.class
    defaultParams = Typologies.getDefaultParameterValues(typologyClass)
    #    defaultParams = Typologies.mergeDefaults(typology ? {})
    console.debug 'updateFields', @, arguments, typologyId, typology, typologyClass
    for key, input of Forms.getSchemaInputs(@, collection)
      fieldSchema = input.field
      isParamField = ParamUtils.hasPrefix(key)
      paramName = ParamUtils.removePrefix(key) if isParamField
      classes = fieldSchema.classes
      classOptions = classes?[typologyClass]
      allClassOptions = classes?.ALL
      if allClassOptions?
        classOptions = _.extend(allClassOptions, classOptions)

      $input = $(input.node)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      # Hide fields which have classes specified which don't contain the current class.
      $wrapper[if classes and not classOptions then 'hide' else 'show']()

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

      # For a dropdown field, show the inherited or default value with labels.
      if $input.is('select')
        origInput = origInputs[key]
        if origInput
          # This field has been modified before - replace with a clone of the original.
          $origInput = origInputs[key].clone()
          $input.replaceWith($origInput)
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
        entity = @data.doc
        entityValue = SchemaUtils.getParameterValue(entity, paramName) if entity
          # Only show None if we don't have a set or inherited value
        unless entityValue?
          if typologyValue?
            $input.val(typologyValue)
          else if defaultValue?
            $input.val(defaultValue)
          else
            # TODO(aramk) This is not available if a value or default value exists, since we cannot
            # override with null yet.
            $option = $('<option value="">None</option>')
            $input.prepend($option)
            $input.val('')

  Form = Forms.defineModelForm
    name: 'entityForm'
    collection: collection
    onRender: ->
      updateFields.call(@)
      $typologyInput = getTypologyInput.call(@)
      $typologyInput.on 'change', => updateFields.call(@)
    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc
      before:
        update: (docId, modifier, template) ->
          # Prevent the the lack of space fields from causing them to be removed.
          delete modifier.$unset?['parameters.space']
          modifier


  Form.helpers
    typologies: -> Typologies.findByProject()
