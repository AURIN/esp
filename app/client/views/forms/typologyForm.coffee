Meteor.startup ->
  Form = Forms.defineModelForm
    name: 'typologyForm'
    collection: 'Typologies'
    onRender: ->
      typologyClass = Typologies.getParameter(@data.doc, 'general.class')
      console.log 'rendered', @, arguments, typologyClass
      unless typologyClass
        console.warn 'Typology class not defined'
      else
        # Add placeholders for default values
        for key, input of @schemaInputs
          console.log $(input.node)
          classOptions = input.field.classes?[typologyClass]
          console.log 'classOptions', classOptions
          unless classOptions
            continue
          $(input.node).attr('placeholder', classOptions?.defaultValue)
