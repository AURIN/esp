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
  m: 'm'
  m2: 'm^2'
  $m2: '$/m^2'
  $: '$'
  deg: 'degrees'
  kgco2: 'kg CO_2-e'
  Lyear: 'L/year'
  MLyear: 'ML/year'
  kWyear: 'kWh/year'

# Common field schemas shared across collection schemas.

classSchema =
  type: String
  desc: stringAllowedValues(ClassNames)
  optional: false
  allowedValues: ClassNames

heightSchema =
  type: Number
  decimal: true
  desc: 'Height of the typology at its maximum point.'
  units: Units.m

projectSchema =
  label: 'Project'
  type: String
  index: true

descSchema =
  label: 'Description'
  type: String
  optional: true

creatorSchema =
  label: 'Creator'
  type: String
  optional: true

areaSchema =
  label: 'Area'
  type: Number
  desc: 'Area of the land parcel.'
  decimal: true
  units: Units.m2

extendSchema = (orig, changes) ->
  _.extend({}, orig, changes)

categories =
  general:
    items:
    # Generic fields
      state:
        type: String
        desc: 'State for which the typology was prepared (impacts water demand).'
      code:
        type: String
        desc: 'A unique code derived from the state abbreviation, typology type abbreviation and version number. Ex. VIC-CG-001 for Community Garden version 1.'
      class: classSchema
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
        desc: 'Number of occupants in the typology.'
        classes:
          RESIDENTIAL:
            defaultValue: 300
      jobs:
        label: 'No. Jobs'
        type: Number
        desc: 'Number of jobs in the typology.'
        classes:
          COMMERCIAL:
            defaultValue: 200
  space:
    items:
      geom:
        label: 'Geometry'
        type: String,
        desc: '3D Geometry of the typology envelope.'
    # TODO(aramk) Need to discuss how we handle this wrt the lot.
      lotsize: extendSchema(areaSchema, {
        label: 'Lot Size'
        classes:
          RESIDENTIAL:
            defaultValue: 500
          COMMERCIAL:
            defaultValue: 300
      })
      extland:
        label: 'Extra Land'
        type: Number
        decimal: true
        desc: 'Area of the land parcel not covered by the structural improvement.'
        units: Units.m2
        calc: '$space.lotsize - $space.fpa'
      fpa:
      # TODO(aramk) This should eventually be an output parameter calculated from AREA(geom).
        label: 'Footprint Area'
        type: Number
        decimal: true
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
          if lotsize.isSet && lotsize.operator != '$unset' && this.isSet && this.operator != '$unset' && this.value > lotsize.value
            'Footprint Area must be less than or equal to the Lot Size'
      height: heightSchema
  energy:
    items:
      en_heat:
        label: 'Energy – Heating'
        type: Number
        decimal: true
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
        decimal: true
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
        decimal: true
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
        decimal: true
        units: Units.kgco2
        desc: 'CO2 emissions due to cooling the typology'
        calc: (param) ->
          src = param('energy.src_cool')
          en = param('energy.en_cool')
          return null unless src? and en?
          energySource = EnergySources[src]
          if energySource then energySource.kgCO2 * en else null
  financial:
    items:
    # TODO(aramk) This was used as a demo of using global parameters in an expression.
      local_land_value:
        label: 'Land Value'
        type: Number
        decimal: true
        desc: 'Total land value of the precinct.'
        units: Units.$
        calc: (param) ->
          param('financial.land_value') * param('space.lotsize')
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
# TYPOLOGY SCHEMA DEFINITION
####################################################################################################

@ParametersSchema = createCategoriesSchema
  categories: categories

TypologySchema = new SimpleSchema
  name:
    label: 'Name'
    desc: 'The full name of the typology.'
    type: String
    index: true
  desc: extendSchema(descSchema,
    {desc: 'A detailed description of the typology, including a summary of the materials and services provided.'})
  parameters:
    label: 'Parameters'
    type: ParametersSchema
  # Necessary to allow fields within to be required.
    optional: false
    defaultValue: {}
  project: projectSchema

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
  Setter.defaults(model.parameters, defaults)
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

findForProject = (collection, projectId) ->
  projectId ?= Projects.getCurrentId()
  if projectId
    collection.find({project: projectId})
  else
    console.error('Project ID not provided - cannot retrieve models.')
    []

Typologies.findForProject = (projectId) -> findForProject(Typologies, projectId)

####################################################################################################
# ENTITY SCHEMA DEFINITION
####################################################################################################

# Entities don't need the class parameter since they reference the typology.
entityCategories = lodash.cloneDeep(categories)
delete entityCategories.general.items.class
@EntityParametersSchema = createCategoriesSchema
  categories: entityCategories

EntitySchema = new SimpleSchema
  name:
    label: 'Name'
    type: String
    index: true
  desc: descSchema
  typology:
    label: 'Typology'
    type: String
    optional: true
  parameters:
    label: 'Parameters'
    type: EntityParametersSchema
  # Necessary to allow required fields within.
    optional: false
    defaultValue: {}
  project: projectSchema

@Entities = new Meteor.Collection 'entities', schema: EntitySchema
Entities.schema = EntitySchema
Entities.allow(Collections.allowAll())

Entities.getFlattened = ->
  cursor = Entities.findForProject()
  entities = cursor.fetch()
  for entity in entities
    Entities.mergeTypology(entity)
  entities

Entities.mergeTypology = (entity) ->
  typologyId = entity.typology
  if typologyId?
    typology = entity._typology = Typologies.findOne(typologyId)
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

Entities.findForProject = (projectId) -> findForProject(Entities, projectId)

####################################################################################################
# LOTS SCHEMA DEFINITION
####################################################################################################

lotCategories =
  general:
    items:
    # If provided, this restricts the class of the entity.
      class: extendSchema(classSchema, {optional: true})
      enabled:
        label: 'Enabled'
        type: Boolean
        desc: 'Whether the lot can have entities placed inside.'
        defaultValue: true
  space:
    items:
      geom:
        label: 'Geometry'
        type: String,
        desc: '3D Geometry of the lot envelope.'
      height: extendSchema(heightSchema,
        {label: 'Allowable Height', desc: 'The maximum allowable height for structures in this lot.'})
      area: areaSchema

@LotParametersSchema = createCategoriesSchema
  categories: lotCategories

LotSchema = new SimpleSchema
  name:
    label: 'Name'
    type: String
    desc: 'The full name of the lot.'
  desc: descSchema
  entity:
    label: 'Entity'
    type: String
    optional: true
  parameters:
    label: 'Parameters'
    type: LotParametersSchema
  project: projectSchema

@Lots = new Meteor.Collection 'lots', schema: LotSchema
Lots.schema = LotSchema
Lots.allow(Collections.allowAll())

#Lots.fromC3ml = (c3mls, callback) ->
#  lotIds = []
#  doneCalls = 0
#  polygonC3mls = []
#  done = (id) ->
#    lotIds.push(id)
#    doneCalls++
#    console.debug('done', id, doneCalls, c3mls.length)
#    if doneCalls == polygonC3mls.length
#      callback(lotIds)
#  _.each c3mls, (c3ml) ->
#    if c3ml.type == 'polygon'
#      polygonC3mls.push(c3ml)
#  _.each polygonC3mls, (c3ml, i) ->
#    coords = c3ml.coordinates
#    # TODO(aramk) Use the names from meta-data
#    name = 'Lot #' + (i + 1)
#    # C3ml coordinates are in (longitude, latitude), but WKT is the reverse.
#    WKT.swapCoords coords, (coords) ->
#      WKT.fromVertices coords, (wkt) ->
#        lot = {
#          name: name
#          project: Projects.getCurrentId()
#          parameters:
#            # TODO(aramk) pass extra args for this.
##            general:
##              class: null
#            space:
#              geom: wkt
#              height: c3ml.height
#        }
#        id = Lots.insert(lot)
#        console.debug('lot', id, lot)
#        done(id)

####################################################################################################
# PROJECTS SCHEMA DEFINITION
####################################################################################################

projectCategories =
  general:
    items:
      creator:
      # TODO(aramk) Integrate this with users.
        type: String
        desc: 'Creator of the project or precinct.'
        optional: false
  location:
    items:
      country:
        type: String
        desc: 'Country of precinct: either Australia or New Zealand.'
        allowedValues: ['Australia', 'New Zealand']
        optional: false
      ste_reg:
        label: 'State, Territory or Region'
        type: String
        desc: 'State, territory or region in which the precinct is situated.'
        optional: false
      loc_auth:
        label: 'Local Government Authority'
        type: String
        desc: 'Local government authority in which this precinct predominantly or completely resides.'
        optional: false
      suburb:
        label: 'Suburb'
        type: String
        desc: 'Suburb in which this precinct predominantly or completely resides.'
      post_code:
        label: 'Post Code'
        type: Number
        desc: 'Post code in which this precinct predominantly or completely resides.'
      sa1_code:
        label: 'SA1 Code'
        type: Number
        desc: 'SA1 in which this precinct predominantly or completely resides.'
      lat:
        label: 'Latitude'
        type: Number
        decimal: true
        units: Units.deg
        desc: 'The latitude coordinate for this precinct'
        optional: false
      lng:
        label: 'Longitude'
        type: Number
        decimal: true
        units: Units.deg
        desc: 'The longitude coordinate for this precinct'
        optional: false
      cam_elev:
        label: 'Camera Elevation'
        type: Number
        decimal: true
        units: Units.m
        desc: 'The starting elevation of the camera when viewing the project.'
  space:
    items:
      geom:
        label: 'Geometry'
        type: String
        desc: '3D Geometry of the precinct envelope.'
      area:
        label: 'Precinct Area'
        type: Number
        decimal: true
        desc: 'Total land area of the precinct.'
        units: Units.m2
# TODO(aramk) This would eventually be calculated using the area of geom.
  environment:
    items:
      climate_zn:
        label: 'Climate Zone'
        type: Number
        decimal: true
        desc: 'BOM climate zone number to determine available typologies.'
      vpsm:
        label: 'Land Value per Square Metre'
        type: Number
        decimal: true
        desc: 'Land value per square metre of the precinct.'
  financial:
    items:
      land_value:
        label: 'Land Value'
        type: Number
        desc: 'Total land value of the precinct.'
        units: Units.$

ProjectParametersSchema = createCategoriesSchema
  categories: projectCategories

Projectschema = new SimpleSchema
  name:
    label: 'Name'
    type: String,
    index: true,
    unique: true
  desc: descSchema
  creator: creatorSchema
  parameters:
    label: 'Parameters'
    type: ProjectParametersSchema
    optional: false
    defaultValue: {}

@Projects = new Meteor.Collection 'project', schema: Projectschema
Projects.allow(Collections.allowAll())

Projects.setCurrentId = (id) -> Session.set('projectId', id)
Projects.getCurrent = ->
  id = Projects.getCurrentId()
  Projects.findOne(id)
#  Session.get('project')
Projects.getCurrentId = -> Session.get('projectId')

Projects.getLocationAddress = (id) ->
  project = Projects.findOne(id)
  location = project.parameters.location
  components = [location.suburb, location.loc_auth, location.ste_reg, location.country]
  (_.filter components, (c) -> c?).join(', ')

Projects.getLocationCoords = (id) ->
  project = Projects.findOne(id)
  location = project.parameters.location
  {latitude: location.lat, longitude: location.lng, elevation: location.cam_elev}
