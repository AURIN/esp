TemplateClass = Template.dwellingChart

TemplateClass.helpers
  items: ->
    items = []
    entities = @entities
    subclasses = {}
    paramIds = ['space.num_0br', 'space.num_1br', 'space.num_2br', 'space.num_3plus']
    _.each entities, (entity) ->
      typology = Typologies.findOne(entity.typology)
      subclass = SchemaUtils.getParameterValue(typology, 'general.subclass')
      subclasses[subclass] ?= 0
      _.each paramIds, (paramId) ->
        count = SchemaUtils.getParameterValue(entity, paramId)
        if Numbers.isDefined(count)
          subclasses[subclass] += count

    _.each subclasses, (count, subclass) ->
      args = Typologies.Classes.RESIDENTIAL.subclasses[subclass]
      item =
        label: subclass
        value: count
        units: 'Dwellings'
        color: args.color
      items.push(item)
    items

  settings: ->
    {
      title: 'Dwelling Mix by Subclass'
      labels: false
      height: 200
      resize: {width: true}
    }
