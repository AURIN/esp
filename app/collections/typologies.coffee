# TODO(aramk) Add desc for each and show as tooltips in the inputs
# TODO(aramk) Added units for each and show in labels - or just add them into the labels below.

categories =
  general:
    label: 'General'
    items:
      geom:
        label: 'Geometry'
        type: String,
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
      tot_area:
        label: 'Total Area'
        type: Number
  environmental:
    label: 'Environmental'
    items:
      pav_prpn:
        label: 'Proportion Paved'
        type: Number
      pav_area:
        label: 'Area Paved'
        type: Number
      nat_prpn:
        label: 'Proportion Native Plants'
        type: Number
      nat_area:
        label: 'Area of Native Plants'
        type: Number
      exo_prpn:
        label: 'Proportion Exotic Plants'
        type: Number
      exo_area:
        label: 'Area of Exotic Plants'
        type: Number
      lawn_prpn:
        label: 'Proportion Lawn'
        type: Number
      lawn_area:
        label: 'Area of Lawn'
        type: Number

# Constructs schemas for the categories and their items specified above.
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
    type: String,
    index: true,
    unique: true
  desc:
    label: 'Description'
    type: String
  parameters:
    label: 'Parameters'
    type: ParametersSchema
  # TODO(aramk) Descriptions cannot be given - considered invalid field.
#    desc: 'This is a simple description'
    optional: true

@Typologies = new Meteor.Collection 'typologies', schema: Schema
Typologies.schema = Schema
Typologies.allow(Collections.allowAll())
