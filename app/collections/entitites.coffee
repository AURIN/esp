schema = new SimpleSchema
  name:
    label: 'Name'
    type: String
    index: true,
    unique: true
  desc:
    label: 'Description'
    type: String
    optional: true
  typology:
    label: 'Typology'
    type: String
    optional: true

@Entities = new Meteor.Collection 'entities', schema: schema
Entities.schema = schema
Entities.allow(Collections.allowAll())

Entities.getWithTypology = ->
  cursor = Entities.find.apply(Entities, arguments)
  entities = cursor.fetch()
  for entity in entities
    Entities.mergeTypology(entity)
  entities

Entities.mergeTypology = (entity) ->
  typologyId = entity.typology
  if typologyId?
    entity.typology = Typologies.findOne(typologyId)
  entity
