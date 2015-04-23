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
      requirejs ['atlas/util/NumberFormatter'], (NumberFormatter) =>
        formatter = new NumberFormatter()
        for field in fields
          try
            args =
              field: field
              results: results
              formatter: formatter
              data: data
              entities: entities
            renderedField = Reports.renderField(args)
            renderedFields.push(renderedField)
            $fields.append(renderedField.element)
          catch e
            console.error('Failed report field render', e)
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

    Report.helpers
      reportData: ->
        title: title

  renderField: (args) ->
    renderData = @fieldToRenderData(args)
    renderedField =
      data: renderData
      element: @fieldToRenderElement(args)

  fieldToRenderData: (args) ->
    field = args.field
    data = args.data
    param = field.param
    unless param?
      return Setter.clone(field)
    paramSchema = ParamUtils.getParamSchema(param)
    unless paramSchema
      throw new Error('Could not find schema for param: ' + param)
    label = field.label ? paramSchema.label ? Strings.toTitleCase(param)
    units = paramSchema.units
    value = data[field.id]
    if Number.isNaN(value)
      value = null
    Setter.merge(field, {label: label, value: value, units: units})

  fieldToRenderElement: (args) ->
    field = args.field
    if field.param?
      return @renderParamField(args)
    else if field.title?
      return $('<div class="subtitle">' + field.title + '</div>')
    else if field.subtitle?
      return $('<div class="subsubtitle">' + field.subtitle + '</div>')
    else if field.template?
      return @renderTemplateField(args)

  renderParamField: (args) ->
    field = args.field
    formatter = args.formatter
    param = field.param
    units = field.units
    label = field.label
    value = field.value
    paramSchema = ParamUtils.getParamSchema(param)
    type = paramSchema.type
    unless Numbers.isDefined(value)
      value = 'N/A'
    else if type == Number
      unless value == Infinity || value == -Infinity
        decimalPoints = paramSchema.decimalPoints ? 2
        unless paramSchema.decimal
          decimalPoints = 0
        # Round the value using the formatter to a fixed set of decimal points, otherwise it's hard
        # to compare values.
        value = formatter.round(value, {minSigFigs: decimalPoints, maxSigFigs: decimalPoints})
    $field = $('<div class="field"></div>')
    $label = $('<div class="label"><div class="content">' + label + '</div></div>')
    if units?
      $label.append('<div class="units">' + Strings.format.scripts(units) + '</div>')
    $value = $('<div class="value">' + value + '</div>')
    $field.append($label, $value)
    $field

  renderTemplateField: (args) ->
    field = args.field
    $parent = $('<div class="template field"></div>')
    data = _.extend(Setter.clone(args))
    view = Blaze.renderWithData(Template[field.template], data, $parent[0])
    $parent

  toCSV: (renderedFields) ->
    csv = new Csv()
    csv.addRow ['ID', 'Label', 'Category', 'Units', 'Value']
    currentCategory = ''
    _.each renderedFields, (field) ->
      data = field.data
      title = data.title
      if title
        currentCategory = title
        return
      csv.addRow [data.param, data.label, currentCategory, data.units, data.value]
    csv.toString()

