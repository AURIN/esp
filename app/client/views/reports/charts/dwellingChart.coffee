TemplateClass = Template.dwellingChart

TemplateClass.helpers
  items: ->
    items = []
    entities = @entities
    console.log('entities', entities)
    subclasses = {}
    _.each entities, (entity) ->
      typology = Typologies.findOne(entity.typology)
      subclass = SchemaUtils.getParameterValue(typology, 'general.subclass')
      subclasses[subclass] ?= 0
      subclasses[subclass]++

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
