Meteor.startup ->

  getTypologyInput = ->
    $(@.find('[name="typology"]')).closest('.dropdown')

  getTypologyInputValue = ->
    getTypologyInput.call(@).dropdown('get value')

  updateFields = ->
    typologyId = getTypologyInputValue.call(@)
    typology = Typologies.findOne(typologyId)
    typologyClass = typology.parameters?.general?.class
    unless typologyClass
      console.warn('No typology class found.')
      return
    console.debug 'updateFields', @, arguments, typologyId, typology, typologyClass
    for key, input of @schemaInputs
      console.debug 'input', key, input
      paramName = key.replace(/^parameters\./, '')
      classes = input.field.classes
      classOptions = if classes and typologyClass then classes[typologyClass] else null
      typologyValue = Typologies.getParameter(typology, paramName)
      console.debug 'typologyValue', typologyValue, classOptions
      $input = $(input.node)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      if typologyValue?
        # Add placeholders for inherited values
        $input.attr('placeholder', typologyValue)
      else if classOptions
        # Add placeholders for default values
        $input.attr('placeholder', classOptions.defaultValue)
      # Hide fields which have classes specified which don't contain the current class.
      $wrapper[if classes and not classOptions then 'hide' else 'show']()
      # For a dropdown field, show the inherited value or an empty value as the first option
      if $input.is('select')
        # TODO(aramk) Currently not possible to override a value with null - it must either inherit
        # or be the default value (which could be null).
        if typologyValue?
          label = 'Inherited (' + typologyValue + ')'
        else if classOptions?.defaultValue?
          label = 'Default (' + classOptions.defaultValue + ')'
        else
          label = 'None'
        $option = $('<option value="">' + label + '</option>')
        $input.prepend($option)
        # If the currently selected value is not actually present in the data, select the new first
        # option.
        entity = @data.doc
        entityValue = Entities.getParameter(entity, paramName)
        unless entityValue?
          $input.val('')

  Form = Forms.defineModelForm
    name: 'entityForm'
    collection: 'Entities'
    onSubmit: (insertDoc, updateDoc, currentDoc) ->
      console.log 'insertDoc', insertDoc, 'updateDoc', updateDoc, 'currentDoc', currentDoc
      console.log ''
    onRender: ->
      updateFields.call(@)
      $typologyInput = getTypologyInput.call(@)
      $typologyInput.on 'change', => updateFields.call(@)

  Form.helpers
    typology: -> @doc?.typology
