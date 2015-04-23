TemplateClass = Template.landUseChart

TemplateClass.helpers
  items: ->
    entities = @entities
    items = {}
    paramId = 'space.lotsize'
    field = Collections.getField(Typologies, 'parameters.' + paramId)
    _.each Typologies.LandClasses, (args, typologyClass) ->
      args = Typologies.Classes[typologyClass]
      items[typologyClass] =
        label: args.name
        units: field.units
        color: args.color
        value: 0
      _.each entities, (entity) ->
        typology = Typologies.findOne(entity.typology)
        entityClass = SchemaUtils.getParameterValue(typology, 'general.class')
        return unless entityClass == typologyClass
        EntityUtils.evaluate(entity, paramId)
        value = SchemaUtils.getParameterValue(entity, paramId)
        if Numbers.isDefined(value)
          items[typologyClass].value += value
    items

  settings: ->
    {
      title: 'Land Use Mix'
      labels: false
      height: 200
      resize: {width: true}
    }
