TemplateClass = Template.bedroomChart

TemplateClass.helpers
  items: ->
    entities = @entities
    counts = {}
    paramIds = ['space.num_0br', 'space.num_1br', 'space.num_2br', 'space.num_3plus']
    _.each paramIds, (paramId) ->
      field = Collections.getField(Typologies, 'parameters.' + paramId)
      counts[paramId] =
        label: field.label
        units: field.units
        value: 0
      _.each entities, (entity) ->
        EntityUtils.evaluate(entity, paramId)
        count = SchemaUtils.getParameterValue(entity, paramId)
        if Numbers.isDefined(count)
          counts[paramId].value += count
    counts

  settings: ->
    {
      title: 'Dwelling Mix by Bedrooms'
      labels: false
      height: 200
      resize: {width: true}
    }
