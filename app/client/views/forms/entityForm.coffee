Meteor.startup ->

  getTypologyInput = ->
    $(@.find('[name="typology"]')).closest('.dropdown')

  getTypologyInputValue = ->
    getTypologyInput.call(@).dropdown('get value')

  getSelectOption = (value, $select) ->
    $('option[value="' + value + '"]', $select)

  updateFields = ->
    typologyId = getTypologyInputValue.call(@)
    typology = Typologies.findOne(typologyId)
    typologyClass = typology?.parameters?.general?.class
    console.debug 'updateFields', @, arguments, typologyId, typology, typologyClass
    for key, input of @schemaInputs
      console.debug 'input', key, input
      paramName = key.replace(/^parameters\./, '')
      classes = input.field.classes
      classOptions = if classes and typologyClass then classes[typologyClass] else null
      typologyValue = if typology then Typologies.getParameter(typology, paramName) else null
      defaultValue = classOptions?.defaultValue
      console.debug 'typologyValue', typologyValue, classOptions
      $input = $(input.node)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      if typologyValue?
        # Add placeholders for inherited values
        $input.attr('placeholder', typologyValue)
      else if defaultValue
        # Add placeholders for default values
        $input.attr('placeholder', defaultValue)
      # Hide fields which have classes specified which don't contain the current class.
      $wrapper[if classes and not classOptions then 'hide' else 'show']()
      # For a dropdown field, show the inherited or default value with labels.
      if $input.is('select')
        if typologyValue?
          $inheritedOption = getSelectOption(typologyValue, $input);
          if $inheritedOption.length > 0
            $inheritedOption.text($inheritedOption.text() + ' (Inherited)')
            inputValue = $input.val()
            console.log 'inputValue', inputValue
            if inputValue == null || inputValue == typologyValue
              # Either no value is selected, or the inherited value is selected. Remove the value
              # from the option and select it.
              $input.val(typologyValue)
            $inheritedOption.val('')
        if defaultValue?
          # Label which option is the default value.
          $defaultOption = getSelectOption(defaultValue, $input);
          if $defaultOption.length > 0
            $defaultOption.text('Default (' + $defaultOption.text() + ')')
        entity = @data.doc
        entityValue = if entity then Entities.getParameter(entity, paramName) else
        # Only show None if we don't have a set or inherited value
        if !entityValue? && !typologyValue?
          # TODO(aramk) This is not available if a value exists, since we cannot override with null
          # yet.
          $option = $('<option value="">None</option>')
          $input.prepend($option)
          $input.val('')

  Form = Forms.defineModelForm
    name: 'entityForm'
    collection: 'Entities'
    onRender: ->
      updateFields.call(@)
      $typologyInput = getTypologyInput.call(@)
      $typologyInput.on 'change', => updateFields.call(@)
    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  Form.helpers
    typologies: -> Typologies.findForProject()
