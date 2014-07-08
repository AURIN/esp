Meteor.startup ->
  addTypology = (doc, template) ->
    $dropdown = $(template.find('.typology-class.dropdown'))
    value = $dropdown.dropdown('get value')
    # TODO(aramk) Format is different?
    doc['parameters.general.class'] ?= value
    doc

  Form = Forms.defineModelForm
    name: 'typologyForm'
    collection: 'Typologies'
    onRender: ->
      typologyClass = Typologies.getParameter(@data.doc, 'general.class')
      unless typologyClass
        console.warn 'Typology class not defined'
      else
        # Add placeholders for default values
        for key, input of @schemaInputs
          classOptions = input.field.classes?[typologyClass]
          if classOptions
            $(input.node).attr('placeholder', classOptions?.defaultValue)
    hooks:
      before:
        insert: addTypology
        update: (docId, modifier, template) ->
          addTypology(modifier.$set, template)
          modifier
  Form.helpers
    classes: -> _.map Typologies.classes, (name, id) -> {_id: id, name: name}
    classValue: -> @doc?.parameters?.general?.class

