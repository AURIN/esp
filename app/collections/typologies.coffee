# TODO(aramk) Add desc for each and read in a custom form input template if necessary.

schema = new SimpleSchema
  name:
    label: 'Name'
    type: String
  desc:
    label: 'Description'
    type: String
  geom:
    label: 'Geometry'
    type: Object,
    optional: true
  state:
    label: 'State'
    type: String
  code:
    label: 'Code'
    type: String
  'class':
    label: 'Class'
    type: String
  subclass:
    label: 'Subclass'
    type: String
  type:
    label: 'Type'
    type: String

@Typologies = new Meteor.Collection 'typologies', schema: schema
Typologies.schema = schema

Typologies.allow(Collections.allowAll())
