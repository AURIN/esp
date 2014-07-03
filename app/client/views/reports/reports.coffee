@Reports =

  define: (args) ->
    name = args.name
    title = args.title
    Report = Template[name]
    unless Report
      throw new Error 'No template defined with name ' + name

    # Flatten the list of fields, which may contain arrays of fields as items
    fields = []
    for field in args.fields
      if Types.isObjectLiteral(field)
        fields.push field
      else if Types.isArray(field)
        for item in field
          fields.push item
      else
        throw new Error('Invalid argument type for field: ' + field)

    Report.rendered = ->
      # TODO(aramk) Invoke generator first, then pass data to renderField

      $fields = $(@find('.fields'))
      for field in fields
        $field = Reports.renderField(field)
        $fields.append($field)

    Report.helpers
      reportData: ->
        title: title

    Report

  defineParamFields: (args) ->
    fields = []
    for paramId in params
      fields = {param: args.category + '.' + paramId}
    fields

  renderField: (field) ->
    if field.param?
      # TODO(aramk) Actually generate the field
      return $('<div class="field">' + field.param + '</div>')
    else if field.title?
      return $('<div class="subtitle">' + field.title + '</div>')
