# TODO(aramk) Add desc for each and show as tooltips in the inputs
# TODO(aramk) Added units for each and show in labels - or just add them into the labels below.

classes = ['Residential', 'Commercial', 'Mixed Use', 'Institutional', 'Road', 'Public Open Space']
types = ['Basic', 'Energy Efficient']

categories =
  general:
    label: 'General'
    items:
      geom:
        label: 'Geometry'
        type: String,
        desc: '3D Geometry of the typology envelope.'
      state:
        label: 'State'
        type: String
        desc: 'State for which the typology was prepared (impacts water demand).'
      code:
        label: 'Code'
        type: String
        desc: 'A unique code derived from the state abbreviation, typology type abbreviation and version number. Ex. VIC-CG-001 for Community Garden version 1.'
      'class':
        label: 'Class'
        type: String
        allowedValues: classes
      subclass:
        label: 'Subclass'
        type: String
        desc: 'Typology within a class. Ex. "Community Garden", "Park" or "Public Plaza".'
      type:
        label: 'Type'
        type: String
        desc: 'Version of the subclass.'
        allowedValues: types
      tot_area:
        label: 'Total Area'
        type: Number
        desc: 'Total area of the drawn public open space.'
  environmental:
    label: 'Environmental'
    items:
      pav_prpn:
        label: 'Proportion Paved'
        desc: 'Proportion of the public open space that is paved.'
        type: Number
      pav_area:
        label: 'Area Paved'
        desc: 'Area of the drawn public open space covered by pavement.'
        type: Number
      nat_prpn:
        label: 'Proportion Native Plants'
        desc: 'Proportion of the public open space typology covered by native plants.'
        type: Number
      nat_area:
        label: 'Area of Native Plants'
        desc: 'Area of the drawn public open space covered by native plants.'
        type: Number
      exo_prpn:
        label: 'Proportion Exotic Plants'
        desc: 'Proportion of the public open space covered by exotic plants.'
        type: Number
      exo_area:
        label: 'Area of Exotic Plants'
        desc: 'Area of the drawn public open space covered by exotic plants.'
        type: Number
      lawn_prpn:
        label: 'Proportion Lawn'
        desc: 'Proportion of the public open space covered by lawn.'
        type: Number
      lawn_area:
        label: 'Area of Lawn'
        desc: 'Area of the drawn public open space covered by lawn.'
        type: Number

# Constructs SimpleSchema for the categories and their items specified above.
createCategoriesSchema = (args) ->
  args ?= {}
  cats = args.categories
  unless cats
    throw new Error('No categories provided.')
  catsFields = {}
  for catId, cat of cats
    catSchemaFields = {}
    for itemId, item of cat.items
      itemFields = _.extend({optional: true}, args.itemDefaults, item)
      catSchemaFields[itemId] = itemFields
    catSchema = new SimpleSchema(catSchemaFields)
    catFields = _.extend({optional: true}, args.categoryDefaults, cat, {type: catSchema})
    delete catFields.items
    catsFields[catId] = catFields
  new SimpleSchema(catsFields)

ParametersSchema = createCategoriesSchema
  categories: categories

Schema = new SimpleSchema
  name:
    label: 'Name'
    desc: 'The full name of the typology.'
    type: String,
    index: true,
    unique: true
  desc:
    label: 'Description'
    desc: 'A detailed description of the typology, including a summary of the materials and services provided.'
    type: String
  parameters:
    label: 'Parameters'
    type: ParametersSchema
    optional: true

@Typologies = new Meteor.Collection 'typologies', schema: Schema
Typologies.schema = Schema
Typologies.allow(Collections.allowAll())
