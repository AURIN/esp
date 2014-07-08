Meteor.startup ->

  getClassInput = ->
    $(@.find('.typology-class.dropdown'))

  getClassInputValue = ->
    getClassInput.call(@).dropdown('get value')

  beforeSubmit = (doc, template) ->
    value = getClassInputValue.call(template)
    doc['parameters.general.class'] ?= value
    doc

  updateFields = ->
    typologyClass = getClassInputValue.call(@)
    console.debug 'updateFields', @, arguments, typologyClass
#    unless typologyClass
#      console.warn 'Typology class not defined'
#    else
    for key, input of @schemaInputs
      classes = input.field.classes
      unless classes
        continue
      classOptions = if typologyClass then classes[typologyClass] else null
      $input = $(input.node)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      if classOptions
        # Add placeholders for default values
        $input.attr('placeholder', classOptions.defaultValue)
      # Hide fields which have classes specified which don't contain the current class.
      $wrapper[if classOptions then 'show' else 'hide']()

  Form = Forms.defineModelForm
    name: 'typologyForm'
    collection: 'Typologies'
    onRender: ->
      updateFields.call(@)
      $classInput = getClassInput.call(@)
      $classInput.on 'change', => updateFields.call(@)

    hooks:
      before:
        insert: ->
          doc = beforeSubmit.apply(@, arguments)
          Typologies.unflattenParameters(doc)
          console.debug('inserting', doc)
          doc
        update: (docId, modifier, template) ->
          $set = modifier.$set
          beforeSubmit($set, template) if $set
#          $unset = modifier.$unset
#          Typologies.unflattenParameters($unset) if $unset
          console.debug('updating', modifier)
          modifier

  Form.helpers
    classes: -> _.map Typologies.classes, (name, id) -> {_id: id, name: name}
    classValue: -> @doc?.parameters?.general?.class
