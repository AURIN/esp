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
