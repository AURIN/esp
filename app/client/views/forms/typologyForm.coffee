Meteor.startup ->

  getClassInput = ->
    $(@.find('[name="parameters.general.class"]')).closest('.dropdown')

  getClassInputValue = ->
    getClassInput.call(@).dropdown('get value')

  updateFields = ->
    typology = @data.doc
    typologyClass = getClassInputValue.call(@)
    console.debug 'updateFields', @, arguments, typologyClass
    for key, input of @schemaInputs
      classes = input.field.classes
      classOptions = if classes and typologyClass then classes[typologyClass] else null
      paramName = key.replace(/^parameters\./, '')
      $input = $(input.node)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      if classOptions
        # Add placeholders for default values
        $input.attr('placeholder', classOptions.defaultValue)
      # Hide fields which have classes specified which don't contain the current class.
      $wrapper[if classes and not classOptions then 'hide' else 'show']()
      # Add a "none" option to select fields.
      if $input.is('select')
        label = 'None'
        $option = $('<option value="">' + label + '</option>')
        $input.prepend($option)
        inputValue = if typology then Typologies.getParameter(typology, paramName) else null
        unless inputValue?
          $input.val('')

  Form = Forms.defineModelForm
    name: 'typologyForm'
    collection: 'Typologies'
    onRender: ->
      updateFields.call(@)
      $classInput = getClassInput.call(@)
      $classInput.on 'change', => updateFields.call(@)

  Form.helpers
    classes: -> _.map Typologies.classes, (name, id) -> {_id: id, name: name}
    classValue: -> @doc?.parameters?.general?.class
