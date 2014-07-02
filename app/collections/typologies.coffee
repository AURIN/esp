# TODO(aramk) Add desc for each and read in a custom form input template if necessary.

#categories = ['General', ]

GeneralSchema = new SimpleSchema
  geom:
    label: 'Geometry'
    type: String
    optional: true

EnvironmentalSchema = new SimpleSchema
  geom:
    label: 'Geometry'
    type: String
    optional: true

ParameterSchema = new SimpleSchema
  street:
    type: String
    max: 100
  general:
    label: 'General'
    type: GeneralSchema
    optional: true
  environmental:
    label: 'Environmental'
    type: EnvironmentalSchema
    optional: true

Schema = new SimpleSchema
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
    type: ParameterSchema
    # TODO(aramk) Descriptions cannot be given - considered invalid field.
#    desc: 'This is a simple description'
    optional: true

@Typologies = new Meteor.Collection 'typologies', schema: Schema
Typologies.schema = Schema
Typologies.allow(Collections.allowAll())
