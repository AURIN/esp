@Reports =

  define: (args) ->
    name = args.name
    title = args.title
    typologyClass = args.typologyClass
    Report = Template[name]
    Report.title = title
    unless Report
      throw new Error 'No template defined with name ' + name

    evalEngine = new EvaluationEngine(schema: Entities.schema)
    reportGenerator = new ReportGenerator(evalEngine: evalEngine)

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

    Report.rendered = ->
      # TODO(aramk) Invoke generator first, then pass data to renderField

      # TODO(aramk) Filter based on selected entities/typologies with Session.get
      entityFilter = null
      if typologyClass?
        entityFilter = (entity) ->
          console.log('arguments', arguments)
          typology = Typologies.findOne(entity.typology)
          Typologies.getParameter(typology, 'general.class') == typologyClass
      entities = Entities.getAllFlattened(entityFilter)
      console.log('Evaluating entities', entities)
      results = reportGenerator.generate(models: entities, fields: fields)
      console.log('results', results)

      require(['atlas/util/NumberFormatter'], (NumberFormatter) =>
        formatter = new NumberFormatter();
        $fields = $(@find('.fields'))
        for field in fields
          try
            $field = Reports.renderField(field, results, formatter)
            $fields.append($field)
          catch e
            console.error('Failed report field render: ' + e)
        $footer = $(@find('.footer'))
        count = entities.length
        plural = Strings.pluralize('entity', count, 'entities')
        $footer.text("Assessed #{count} #{plural}")
        # Trigger event to notify any listeners that the report has been rendered.
        $report = $(@find('.report'))
        $report.trigger('render')
      )

    Report.helpers
      reportData: ->
        title: title

    Report

  defineParamFields: (args) ->
    fields = []
    for paramId in params
      fields = {param: args.category + '.' + paramId}
    fields

  renderField: (field, data, formatter) ->
    param = field.param
    if param?
      # TODO(aramk) Actually output the field value
      paramSchema = ParametersSchema.schema(param)
      unless paramSchema
        throw new Error('Could not find schema for param: ' + param)
      label = paramSchema.label ? Strings.toTitleCase(param)
      units = paramSchema.units
      decimalPoints = paramSchema.decimalPoints ? 2
      $field = $('<div class="field"></div>')
      $label = $('<div class="label"><div class="content">' + label + '</div></div>')
      if units?
        $label.append('<div class="units">' + Strings.format.scripts(units) + '</div>')
      value = data[field.id] ? 'N/A'
      if Number.isNaN(value) or !value?
        value = 'N/A'
      else if paramSchema.type == Number
        # Round the value using the formatter to a fixed set of decimal points, otherwise it's hard
        # to compare values.
        value = formatter.round(value, {minSigFigs: decimalPoints, maxSigFigs: decimalPoints})
      $value = $('<div class="value">' + value + '</div>')
      $field.append($label, $value)
      $field
    else if field.title?
      return $('<div class="subtitle">' + field.title + '</div>')
