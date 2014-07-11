####################################################################################################
# SCHEMA DECLARATION
####################################################################################################

TypologyClasses = {
  RESIDENTIAL: 'Residential',
  COMMERCIAL: 'Commercial',
  OPEN_SPACE: 'Open Space',
  PATHWAYS: 'Pathways',
}
ClassNames = Object.keys(TypologyClasses)

TypologyTypes = ['Basic', 'Energy Efficient']

# TODO(aramk) Convert to using global parameters.
# Energy sources and their kg of CO2 usage
EnergySources =
  Electricity:
    units: 'kWh'
    kgCO2: 1.31
  Gas:
    units: 'MJ'
    kgCO2: 0.05583

EnergySourceTypes = Object.keys(EnergySources)

stringAllowedValues = (allowed) -> '(' + allowed.join(', ') + ')'

# ^ and _ are converted to superscript and subscript in forms and reports.
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
    # Generic fields
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
      class:
        type: String
        desc: stringAllowedValues(ClassNames)
        optional: false
        allowedValues: ClassNames
      subclass:
        type: String
        desc: 'Typology within a class. Ex. "Community Garden", "Park" or "Public Plaza".'
      type:
        type: String
        desc: 'Version of the subclass. ' + stringAllowedValues(TypologyTypes)
        allowedValues: TypologyTypes
      occupants:
        label: 'No. Occupants'
        type: Number
        decimal: false
        desc: 'Number of occupants in the typology.'
        classes:
          RESIDENTIAL:
            defaultValue: 300
      jobs:
        label: 'No. Jobs'
        type: Number
        decimal: false
        desc: 'Number of jobs in the typology.'
        classes:
          COMMERCIAL:
            defaultValue: 200

  geometry:
    items:
      lotsize:
      # TODO(aramk) This should eventually be an output parameter calculated from AREA(lot).
        label: 'Lot Size'
        type: Number
        desc: 'Area of the land parcel.'
        units: Units.m2
        classes:
          RESIDENTIAL:
            defaultValue: 500
          COMMERCIAL:
            defaultValue: 300
      extland:
        label: 'Extra Land'
        type: Number
        desc: 'Area of the land parcel not covered by the structural improvement.'
        units: Units.m2
        calc: '$geometry.lotsize - $geometry.fpa'
      fpa:
      # TODO(aramk) This should eventually be an output parameter calculated from AREA(geom).
        label: 'Footprint Area'
        type: Number
        desc: 'Area of the building footprint.'
        units: Units.m2
        classes:
          RESIDENTIAL:
            defaultValue: 133.6
          COMMERCIAL:
            defaultValue: 250
        custom: ->
          # Abstract these rules into a single string or function for evaluation.
          lotsize = this.siblingField('lotsize')
          console.log 'custom', lotsize, this
          if lotsize.isSet && lotsize.operator != '$unset' && this.isSet && this.operator != '$unset' && this.value > lotsize.value
            'Footprint Area must be less than or equal to the Lot Size'

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
        allowedValues: EnergySourceTypes
        desc: 'Energy source in the typology used for heating. ' + stringAllowedValues(EnergySourceTypes)
      co2_heat:
        label: 'CO2 – Heating'
        type: Number
        units: Units.kgco2
        desc: 'CO2 emissions due to heating the typology'
        calc: (param) ->
          src = param('energy.src_heat')
          en = param('energy.en_heat')
          return null unless src? and en?
          energySource = EnergySources[src]
          if energySource then energySource.kgCO2 * en else null
      en_cool:
        label: 'Energy – Cooling'
        type: Number
        units: Units.kWyear
        desc: 'Energy required for cooling the typology.'
      src_cool:
        label: 'Energy Source – Cooling'
        type: String
        allowedValues: EnergySourceTypes
        desc: 'Energy source in the typology used for cooling. ' + stringAllowedValues(EnergySourceTypes)
      co2_cool:
        label: 'CO2 – Cooling'
        type: Number
        units: Units.kgco2
        desc: 'CO2 emissions due to cooling the typology'
        calc: (param) ->
          src = param('energy.src_cool')
          en = param('energy.en_cool')
          return null unless src? and en?
          energySource = EnergySources[src]
          if energySource then energySource.kgCO2 * en else null
#  environmental:
#    items:
#      pav_prpn:
#        label: 'Proportion Paved'
#        desc: 'Proportion of the public open space that is paved.'
#        type: Number
#      pav_area:
#        label: 'Area Paved'
#        desc: 'Area of the drawn public open space covered by pavement.'
#        type: Number
#        units: Units.m2
#      nat_prpn:
#        label: 'Proportion Native Plants'
#        desc: 'Proportion of the public open space typology covered by native plants.'
#        type: Number
#        units: Units.m2
#      nat_area:
#        label: 'Area of Native Plants'
#        desc: 'Area of the drawn public open space covered by native plants.'
#        type: Number
#        units: Units.m2
#      exo_prpn:
#        label: 'Proportion Exotic Plants'
#        desc: 'Proportion of the public open space covered by exotic plants.'
#        type: Number
#      exo_area:
#        label: 'Area of Exotic Plants'
#        desc: 'Area of the drawn public open space covered by exotic plants.'
#        type: Number
#        units: Units.m2
#      lawn_prpn:
#        label: 'Proportion Lawn'
#        desc: 'Proportion of the public open space covered by lawn.'
#        type: Number
#      lawn_area:
#        label: 'Area of Lawn'
#        desc: 'Area of the drawn public open space covered by lawn.'
#        type: Number
#        units: Units.m2

####################################################################################################
# AUXILIARY - MUST BE DEFINED BEFORE USE
####################################################################################################

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
    catFields = _.extend({optional: false, defaultValue: {}}, args.categoryDefaults, cat,
      {type: catSchema})
    autoLabel(catFields, catId)
    delete catFields.items
    catsFields[catId] = catFields
  new SimpleSchema(catsFields)

####################################################################################################
# TYPOLOGIES SCHEMA DEFINITION
####################################################################################################

@ParametersSchema = createCategoriesSchema
  categories: categories

TypologySchema = new SimpleSchema
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
    optional: true
  parameters:
    label: 'Parameters'
    type: ParametersSchema
  # Necessary to allow required fields within.
    optional: false
    defaultValue: {}

@Typologies = new Meteor.Collection 'typologies', schema: TypologySchema
Typologies.schema = TypologySchema
Typologies.classes = TypologyClasses
Typologies.allow(Collections.allowAll())

Typologies.getParameter = (model, paramId) ->
  target = model.parameters ?= {}
  segments = paramId.split('.')
  unless segments.length > 0
    return undefined
  for key in segments
    target = target[key]
    unless target?
      break
  target

Typologies.setParameter = (model, paramId, value) ->
  target = model.parameters ?= {}
  segments = paramId.split('.')
  unless segments.length > 0
    return false
  lastSegment = segments.pop()
  for key in segments
    target = target[key] ?= {}
  target[lastSegment] = value
  true

Typologies.unflattenParameters = (doc, hasParametersPrefix) ->
  Objects.unflattenProperties doc, (key) ->
    if !hasParametersPrefix or /^parameters\./.test(key)
      key.split('.')
    else
      null
  doc

# Traverse the given schema and call the given callback with the field schema and ID.
forEachFieldSchema = (schema, callback) ->
  fieldIds = schema._schemaKeys
  for fieldId in fieldIds
    fieldSchema = schema.schema(fieldId)
    if fieldSchema?
      callback(fieldSchema, fieldId)

Typologies.getDefaultParameterValues = _.memoize (typologyClass) ->
  values = {}
  forEachFieldSchema ParametersSchema, (fieldSchema, paramId) ->
    classes = fieldSchema.classes
    # NOTE: This does not look for official defaultValue in the schema, only in the class options.
    defaultValue = if classes then classes[typologyClass]?.defaultValue else null
    if defaultValue?
      values[paramId] = defaultValue
  Typologies.unflattenParameters(values, false)

# Get the parameters which have default values for other classes and should be excluded from models
# of the class.
Typologies.getExcludedDefaultParameters = _.memoize (typologyClass) ->
  excluded = {}
  forEachFieldSchema ParametersSchema, (fieldSchema, paramId) ->
    classes = fieldSchema.classes
    if classes and !classes[typologyClass]
      excluded[paramId] = true
  Typologies.unflattenParameters(excluded, false)

Typologies.mergeDefaults = (model) ->
  model.parameters ?= {}
  typologyClass = model.parameters.general?.class
  defaults = if typologyClass then Typologies.getDefaultParameterValues(typologyClass) else null
  _.defaults(model.parameters, defaults)
  model

# Filters parameters which don't belong to the class assigned to the given model. This does not
# affect reports since only fields matching the class should be included, but is a fail-safe for
# when calculated expressions may conditionally reference fields outside their class, or when
# reports accidentally include fields outside their class.
Typologies.filterParameters = (model) ->
  typologyClass = model.parameters.general?.class
  unless typologyClass?
    return
  excluded = @getExcludedDefaultParameters(typologyClass)
  for categoryName, category of excluded
    modelCategory = model.parameters[categoryName]
    unless modelCategory
      continue
    for paramName of category
      delete modelCategory[paramName]
  model

# Validate that the given model contains all required nested parameters. This is not supported by
# AutoForm, which only treats fields as required if their parents are also present (in this case,
# the category
# TODO(aramk)
Typologies.validateNestedProperties = -> null

####################################################################################################
# ENTITIES SCHEMA DEFINITION
####################################################################################################

entityCategories = lodash.cloneDeep(categories)
delete entityCategories.general.items.class
@EntityParametersSchema = createCategoriesSchema
  categories: entityCategories

EntitySchema = new SimpleSchema
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
#    type: ParametersSchema
    type: EntityParametersSchema
  # Necessary to allow required fields within.
    optional: false
    defaultValue: {}

@Entities = new Meteor.Collection 'entities', schema: EntitySchema
Entities.schema = EntitySchema
Entities.allow(Collections.allowAll())

Entities.getFlattened = ->
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
      Typologies.mergeDefaults(typology)
      entity.parameters ?= {}
      Setter.defaults(entity.parameters, typology.parameters)
      Typologies.filterParameters(entity, typology)
  entity

Entities.getParameter = (model, paramId) ->
  Typologies.getParameter(model, paramId)

Entities.setParameter = (model, paramId, value) ->
  Typologies.setParameter(model, paramId, value)
