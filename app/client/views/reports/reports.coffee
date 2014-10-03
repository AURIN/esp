@Reports =

  define: (args) ->
    name = args.name
    title = args.title
    typologyClass = args.typologyClass
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

    # Assign temporary IDs to the fields.
    for field, i in fields
      field.id = 'field_' + (i + 1)

    Report.title = title
    Report.fields = fields
    Report.typologyClass = typologyClass

    Report.rendered = ->
      data = @data
      results = data.results
      entities = data.entities

      renderedFields = []
      $fields = $(@find('.fields'))
      require(['atlas/util/NumberFormatter'], (NumberFormatter) =>
        formatter = new NumberFormatter();
        for field in fields
          try
            renderedField = Reports.renderField(field, results, formatter)
            renderedFields.push(renderedField)
            $fields.append(renderedField.element)
          catch e
            console.error('Failed report field render: ' + e)
        $header = $(@find('.header'))
        $info = $('<div class="info"></div>')
        $header.append($info)
        count = entities.length
        plural = Strings.pluralize('entity', count, 'entities')
        $info.text("Assessing #{count} #{plural}")
        # Trigger event to notify any listeners that the report has been rendered.
        $report = $(@find('.report'))
        $report.trigger 'render',
          renderedFields: renderedFields
      )

    Report.helpers
      reportData: ->
        title: title

  renderField: (field, data, formatter) ->
    renderObj = @fieldToRenderObject(field, data, formatter)
    renderedField =
      obj: renderObj
      element: @fieldToRenderElement(renderObj)

  fieldToRenderObject: (field, data, formatter) ->
    param = field.param
    unless param?
      return Setter.clone(field)
    paramSchema = ParametersSchema.schema(param)
    unless paramSchema
      throw new Error('Could not find schema for param: ' + param)
    label = field.label ? paramSchema.label ? Strings.toTitleCase(param)
    units = paramSchema.units
    decimalPoints = paramSchema.decimalPoints ? 2
    value = data[field.id] ? 'N/A'
    if Number.isNaN(value) or !value?
      value = 'N/A'
    else if paramSchema.type == Number
      # Round the value using the formatter to a fixed set of decimal points, otherwise it's hard
      # to compare values.
      value = formatter.round(value, {minSigFigs: decimalPoints, maxSigFigs: decimalPoints})
    Setter.merge(Setter.clone(field), {label: label, value: value, units: units})

  fieldToRenderElement: (field) ->
    param = field.param
    if param?
      units = field.units
      label = field.label
      value = field.value
      $field = $('<div class="field"></div>')
      $label = $('<div class="label"><div class="content">' + label + '</div></div>')
      if units?
        $label.append('<div class="units">' + Strings.format.scripts(units) + '</div>')
      $value = $('<div class="value">' + value + '</div>')
      $field.append($label, $value)
      $field
    else if field.title?
      return $('<div class="subtitle">' + field.title + '</div>')

  toCSV: (renderedFields) ->
    # TODO(aramk)
    [
      '"1","val1","val2","val3","val4"',
      '"2","val1","val2","val3","val4"',
      '"3","val1","val2","val3","val4"'
    ].join('\n')

