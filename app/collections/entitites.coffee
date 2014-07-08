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
  parameters:
    label: 'Parameters'
    type: Object
    optional: true
    defaultValue: {}

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
    typology = entity.typology = Typologies.findOne(typologyId)
    if typology?
      entity.parameters ?= {}
      Setter.merge(entity.parameters, typology.parameters)
  entity

Entities.getParameter = (model, paramId) ->
  Typologies.getParameter(model, paramId)
#  value = Typologies.getParameter(model, paramId)
#  unless value == undefined
#    # Check the typology for an inherited parameter
#    unless Types.isObject(model.typology)
#      throw new Error('Typology not merged')
#    value = Typologies.getParameter(model.typology, paramId)
#  value

Entities.setParameter = (model, paramId, value) ->
  Typologies.setParameter(model, paramId, value)
