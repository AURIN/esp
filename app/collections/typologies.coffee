# TODO(aramk) Add desc for each and show as tooltips in the inputs
# TODO(aramk) Added units for each and show in labels - or just add them into the labels below.

classes = ['Residential', 'Commercial', 'Mixed Use', 'Institutional', 'Road', 'Public Open Space']
types = ['Basic', 'Energy Efficient']
# Energy sources and their kg of CO2 usage
energySources =
  Electricity:
    units: 'kWh'
    kgCO2: 1.31
  Gas:
    units: 'MJ'
    kgCO2: 0.05583
energySourceTypes = Object.keys(energySources)

stringAllowedValues = (allowed) -> '(' + allowed.join(', ') + ')'

Units =
  m2: 'm^2'
  $m2: '$/m^2'
  $: '$'
  kgco2: 'kg CO_2-e'
  Lyear: 'L/year'
  MLyear: 'ML/year'
  kWyear: 'kWh/year'

categories =
  general:
    items:
      geom:
        label: 'Geometry'
        type: String,
        desc: '3D Geometry of the typology envelope.'
      state:
        type: String
        desc: 'State for which the typology was prepared (impacts water demand).'
      code:
        type: String
        desc: 'A unique code derived from the state abbreviation, typology type abbreviation and version number. Ex. VIC-CG-001 for Community Garden version 1.'
    # TODO(aramk) Missing from the spec.
      'class':
        type: String
        desc: stringAllowedValues(classes)
        allowedValues: classes
      subclass:
        type: String
        desc: 'Typology within a class. Ex. "Community Garden", "Park" or "Public Plaza".'
      type:
        type: String
        desc: 'Version of the subclass. ' + stringAllowedValues(types)
        allowedValues: types
      lotsize:
        label: 'Lot Size'
        type: Number
        desc: 'Area of the land parcel.'
        units: Units.m2
      # TODO(aramk) Remove once we support an AREA() function using the geom. Define a function
      # for the "expr" field to return the calculated area.
        defaultValue: 500
      extland:
        label: 'Extra Land'
        type: Number
        desc: 'Area of the land parcel not covered by the structural improvement.'
        units: Units.m2
        defaultValue: 300
      occupants:
        label: 'No. Occupants'
        type: Number
        decimal: false
        desc: 'Number of occupants in the typology.'
  energy:
    items:
      en_heat:
        label: 'Energy – Heating'
        type: Number
        units: Units.kWyear
        desc: 'Energy required for heating the typology.'
      src_heat:
        label: 'Energy Source – Heating'
        type: String
        allowedValues: energySourceTypes
        desc: 'Energy source in the typology used for heating. ' + stringAllowedValues(energySourceTypes)
      co2_heat:
        label: 'CO2 – Heating'
        type: Number
        units: Units.kgco2
        desc: 'CO2 emissions due to heating the typology'
        # TODO(aramk) Provide an expression with context and variables instead.
        expr: (params) ->
          src = params.energy.src_heat
          en = params.energy.en_heat
          return null unless src? and en?
          energySource = energySources[params.energy.src_heat]
          if energySource then energySource.kgCO2 * en else null
      en_cool:
        label: 'Energy – Cooling'
        type: Number
        units: Units.kWyear
        desc: 'Energy required for cooling the typology.'
      src_cool:
        label: 'Energy Source – Cooling'
        type: String
        allowedValues: energySourceTypes
        desc: 'Energy source in the typology used for cooling. ' + stringAllowedValues(energySourceTypes)
      co2_cool:
        label: 'CO2 – Cooling'
        type: Number
        units: Units.kgco2
        desc: 'CO2 emissions due to cooling the typology'
        expr: (params) ->
          src = params.energy.src_cool
          en = params.energy.en_cool
          return null unless src? and en?
          energySource = energySources[params.energy.src_cool]
          if energySource then energySource.kgCO2 * en else null
  environmental:
    items:
      pav_prpn:
        label: 'Proportion Paved'
        desc: 'Proportion of the public open space that is paved.'
        type: Number
      pav_area:
        label: 'Area Paved'
        desc: 'Area of the drawn public open space covered by pavement.'
        type: Number
        units: Units.m2
      nat_prpn:
        label: 'Proportion Native Plants'
        desc: 'Proportion of the public open space typology covered by native plants.'
        type: Number
        units: Units.m2
      nat_area:
        label: 'Area of Native Plants'
        desc: 'Area of the drawn public open space covered by native plants.'
        type: Number
        units: Units.m2
      exo_prpn:
        label: 'Proportion Exotic Plants'
        desc: 'Proportion of the public open space covered by exotic plants.'
        type: Number
      exo_area:
        label: 'Area of Exotic Plants'
        desc: 'Area of the drawn public open space covered by exotic plants.'
        type: Number
        units: Units.m2
      lawn_prpn:
        label: 'Proportion Lawn'
        desc: 'Proportion of the public open space covered by lawn.'
        type: Number
      lawn_area:
        label: 'Area of Lawn'
        desc: 'Area of the drawn public open space covered by lawn.'
        type: Number
        units: Units.m2

# AUXILIARY - MUST BE DEFINED BEFORE USE

autoLabel = (field, id) ->
  field.label ?= toTitleCase(id)

# TODO(aramk) Can't use Strings or other utilities outside Meteor.startup since it's not loaded yet
toTitleCase = (str) ->
  parts = str.split(/\s+/)
  title = ''
  for part, i in parts
    if part != ''
      title += part.slice(0, 1).toUpperCase() + part.slice(1, part.length);
      if i != parts.length - 1 and parts[i + 1] != ''
        title += ' '
  title

# END AUXILIARY

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
      # TODO(aramk) Set the default to 0 for numbers.
      itemFields = _.extend({optional: true}, args.itemDefaults, item)
      autoLabel(itemFields, itemId)
      catSchemaFields[itemId] = itemFields
    catSchema = new SimpleSchema(catSchemaFields)
    catFields = _.extend({optional: true}, args.categoryDefaults, cat, {type: catSchema})
    autoLabel(catFields, catId)
    delete catFields.items
    catsFields[catId] = catFields
  new SimpleSchema(catsFields)

@ParametersSchema = createCategoriesSchema
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
