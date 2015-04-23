TemplateClass = Template.dwellingChart

TemplateClass.rendered = ->
  console.log('rendered')
  
TemplateClass.helpers
  items: ->
    # entities = _.filter @entities, (entity) ->
    #   typology = Typologies.findOne(entity.typology)
    #   typologyClass = SchemaUtils.getParameterValue(typology, 'general.class')
    #   typologyClass == 'RESIDENTIAL'

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
      title: 'Dwelling Mix'
      labels: false
      height: 200
      resize: {width: true}
    }
