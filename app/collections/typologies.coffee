# TODO(aramk) Add desc for each and read in a custom form input template if necessary.

schema = new SimpleSchema
  name:
    label: 'Name'
    type: String,
    index: true,
    unique: true
  desc:
    label: 'Description'
    type: String
  geom:
    label: 'Geometry'
    type: Object,
    # Not all typologies will have default geometries - some will only contain parameters.
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
  parameters:
    label: 'Parameters'
    type: Object
    optional: true,
    defaultValue: {}

@Typologies = new Meteor.Collection 'typologies', schema: schema
Typologies.schema = schema
Typologies.allow(Collections.allowAll())
