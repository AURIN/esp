####################################################################################################
# SCHEMA OPTIONS
####################################################################################################

SimpleSchema.debug = true
SimpleSchema.extendOptions
# Optional extra fields.
# TODO(aramk) These are added globally, not just for typologies.
  desc: Match.Optional(String)
  units: Match.Optional(String)
# TODO(aramk) There's no need to use serialized formulas, since functions are first-class objects
# and we don't need to persist or change them outside of source code.

# An expression for calculating the value of the given field for the given model. These are output
# fields and do not appear in forms. The formula can be a string containing other field IDs prefixed
# with '$' (e.g. $occupants) which are resolved to the local value per model, or global parameters
# if no local equivalent is found.

# If the expression is a function, it is passed the current model
# and the field and should return the result.
  calc: Match.Optional(Match.Any)
# A map of class names to objects of properties. "defaultValues" specifies the default value for
# the given class.
  classes: Match.Optional(Object)

####################################################################################################
# SCHEMA DECLARATION
####################################################################################################

TypologyClasses =
  RESIDENTIAL:
    name: 'Residential'
    color: '#009cff' # Blue
  COMMERCIAL:
    name: 'Commercial'
    color: 'red'
  MIXED_USE:
    name: 'Mixed Use'
    color: '#c000ff' # Purple
  OPEN_SPACE:
    name: 'Open Space'
    color: '#7ed700' # Green
  PATHWAY:
    name: 'Pathway'
    color: 'black'

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

calcArea = (id) ->
  entity = AtlasManager.getEntity(id)
  if entity
    entity.getArea()
  else
    throw new Error('GeoEntity not found - cannot calculate area.')

areaSchema =
  label: 'Area'
  type: Number
  desc: 'Area of the land parcel.'
  decimal: true
  decimalPoints: 2
  units: Units.m2
  calc: (param, paramId, model) -> calcArea(model._id)

extendSchema = (orig, changes) ->
  _.extend({}, orig, changes)

typologyCategories =
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
      geom_2d:
        label: 'Geometry'
        type: String
        desc: '2D footprint geometry of the typology.'
      geom_3d:
        label: 'Mesh'
        type: String
        desc: '3D mesh representing the typology.'
      lotsize: extendSchema(areaSchema, {
        label: 'Lot Size'
        calc: (param, paramId, model) ->
          # If the model is a typology, it doesn't have a lot yet, so no lotsize.
          id = model._id
          unless Entities.findOne(id)
            return null
          lot = Lots.findByEntity(id)
          unless lot
            throw new Error('Lot not found for entity.')
          calcArea(lot._id)
      })
      extland: extendSchema(areaSchema, {
        label: 'Extra Land'
        desc: 'Area of the land parcel not covered by the structural improvement.'
        calc: '$space.lotsize - $space.fpa'
      })
      fpa: extendSchema(areaSchema, {
        label: 'Footprint Area'
        desc: 'Area of the building footprint.'
      })
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
  # For each category in the schema.
  catsFields = {}
  for catId, cat of cats
    catSchemaFields = {}
    # For each field in each category
    for itemId, item of cat.items
      # TODO(aramk) Set the default to 0 for numbers.
      itemFields = _.extend({optional: true}, args.itemDefaults, item)
      autoLabel(itemFields, itemId)
      catSchemaFields[itemId] = itemFields
    catSchema = new SimpleSchema(catSchemaFields)
    catSchemaArgs = _.extend({
      optional: false
      defaultValue: {}
#      autoValue: ->
#        console.log('autoValue', this, arguments)
#        {} unless this.isSet
    }, args.categoryDefaults, cat, {type: catSchema})
    autoLabel(catSchemaArgs, catId)
    delete catSchemaArgs.items
    catsFields[catId] = catSchemaArgs
  new SimpleSchema(catsFields)

@ParamUtils =

  _prefix: 'parameters'
  _rePrefix: /^parameters\./
  addPrefix: (id) ->
    if @_rePrefix.test(id)
      id
    else
      @_prefix + '.' + id
  removePrefix: (id) -> id.replace(@_rePrefix, '')

####################################################################################################
# TYPOLOGY SCHEMA DEFINITION
####################################################################################################

@ParametersSchema = createCategoriesSchema
  categories: typologyCategories

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

Typologies.getClassByName = _.memoize (name) ->
  matchedId = null
  sanitize = (str) -> ('' + str).toLowerCase().trim()
  name = sanitize(name)
  for id, cls of TypologyClasses
    if sanitize(cls.name) == name
      matchedId = id
  matchedId

Typologies.getClassItems = ->
  _.map Typologies.classes, (cls, id) -> Setter.merge(Setter.clone(cls), {_id: id})

Typologies.getParameter = (model, paramId) ->
  paramId = ParamUtils.removePrefix(paramId)
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
  paramId = ParamUtils.removePrefix(paramId)
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

findByProject = (collection, projectId) ->
  projectId ?= Projects.getCurrentId()
  if projectId
    collection.find({project: projectId})
  else
    throw new Error('Project ID not provided - cannot retrieve models.')

Typologies.findByProject = (projectId) -> findByProject(Typologies, projectId)

Typologies.getClassMap = (projectId) ->
  typologies = Typologies.findByProject(projectId).fetch()
  typologyMap = {}
  _.each typologies, (typology) ->
    typologyClass = Typologies.getParameter(typology, 'general.class')
    map = typologyMap[typologyClass] ?= []
    map.push(typology)
  typologyMap

####################################################################################################
# ENTITY SCHEMA DEFINITION
####################################################################################################

# Entities don't need the class parameter since they reference the typology.
entityCategories = lodash.cloneDeep(typologyCategories)
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
# Despite having the "entity" field on lots, when a new entity is created it is rendered
# reactively and without a lot reference it will fail.
  lot:
    label: 'Lot'
    type: String
    index: true
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

Entities.getFlattened = (id) ->
  entity = Entities.findOne(id)
  Entities.mergeTypology(entity)
  entity

Entities.getAllFlattened = ->
  entities = Entities.findByProject().fetch()
  _.map entities, (entity) -> Entities.getFlattened(entity._id)

Entities.mergeTypology = (entity) ->
  typologyId = entity.typology
  if typologyId?
    typology = entity._typology = Typologies.findOne(typologyId)
    if typology?
      Typologies.mergeDefaults(typology)
      entity.parameters ?= {}
      Setter.defaults(entity.parameters, typology.parameters)
      Typologies.filterParameters(entity)
  entity

Entities.getParameter = (model, paramId) ->
  Typologies.getParameter(model, paramId)

Entities.setParameter = (model, paramId, value) ->
  Typologies.setParameter(model, paramId, value)

Entities.findByProject = (projectId) -> findByProject(Entities, projectId)

# Remove the entity from the lot when removing the entity.
Entities.find().observe
  removed: (entity) ->
    lot = Lots.findByEntity(entity._id)
    if lot?
      Lots.remove(lot._id, {$unset: {entity: null}})

####################################################################################################
# LOT SCHEMA DEFINITION
####################################################################################################

lotCategories =
  general:
    items:
    # If provided, this restricts the class of the entity.
      class: extendSchema(classSchema, {optional: true})
      develop:
        label: 'For Development'
        type: Boolean
        desc: 'Whether the lot can be used for development.'
        defaultValue: true
  space:
    items:
      geom_2d:
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
    index: true
    custom: ->
      classParamId = 'parameters.general.class'
      developFieldId = 'parameters.general.develop'
      typologyClassField = @siblingField(classParamId)
      developField = @siblingField(developFieldId)
      unless (typologyClassField.isSet && this.isSet && developField.isSet) || @operator == '$unset'
        # TODO(aramk) This isn't guaranteed to work if typology field is not set at same time as
        # entity. Look up the actual value using an ID.
        return 'Class, entity and develop fields must be set together for validation to work, ' +
          'unless entity is being removed.'
      if typologyClassField.operator == '$unset' && @operator != '$unset'
        return 'Class must be present if entity is present.'
      entityId = @value
      unless entityId
        return
      entityTypology = Typologies.findOne(Entities.findOne(entityId).typology)
      entityClass = Typologies.getParameter(entityTypology, classParamId)
      typologyClass = typologyClassField.value
      if typologyClassField.operator != '$unset' && @operator != '$unset' && typologyClass != entityClass
        return 'Entity must have the same class as the Lot. Entity has ' + entityClass +
          ', Lot has ' + typologyClass
      if developField.operator != '$unset' && @operator != '$unset' && !developField.value
        return 'Lot which is not for development cannot have Entity assigned.'
  parameters:
    label: 'Parameters'
    type: LotParametersSchema
  project: projectSchema

@Lots = new Meteor.Collection 'lots', schema: LotSchema
Lots.schema = LotSchema
Lots.allow(Collections.allowAll())

Lots.getParameter = (model, paramId) ->
  Typologies.getParameter(model, paramId)

Lots.setParameter = (model, paramId, value) ->
  Typologies.setParameter(model, paramId, value)

Lots.findByProject = (projectId) -> findByProject(Lots, projectId)
Lots.findByEntity = (entityId) -> Lots.findOne({entity: entityId})
Lots.findForDevelopment = (projectId) ->
  _.filter Lots.findByProject(projectId).fetch(), (lot) ->
    Lots.getParameter(lot, 'general.develop')
Lots.findAvailable = (projectId) ->
  _.filter Lots.findForDevelopment(projectId), (lot) -> !lot.entity

Lots.createEntity = (lotId, typologyId) ->
  df = Q.defer()
  lot = Lots.findOne(lotId)
  typology = Typologies.findOne(typologyId)
  if !lot
    throw new Error('No Lot with ID ' + id)
  else if !typology
    throw new Error('No Typology with ID ' + typologyId)
  # TODO(aramk) Need a warning?
  #  else if lot.entity?
  #    throw new Error('Lot with ID ' + id + ' already has entity')
  classParamId = 'parameters.general.class'
  developParamId = 'parameters.general.develop'
  lotClass = Lots.getParameter(lot, classParamId)
  isForDevelopment = Lots.getParameter(lot, developParamId)
  # If no class is provided, use the class of the entity's typology.
  unless lotClass
    lotClass = Typologies.getParameter(typology, classParamId)

  # Create a new entity for this lot-typology combination and remove the existing one
  # (if any). Name of the entity matches that of the lot.
  newEntity =
    name: lot.name
    typology: typologyId
    project: Projects.getCurrentId()
    lot: lotId
  Entities.insert newEntity, (err, newEntityId) ->
    if err
      df.reject(err)
      return
    lotModifier = {entity: newEntityId}
    # These are necessary to ensure validation has all fields available.
    lotModifier[classParamId] = lotClass
    lotModifier[developParamId] = isForDevelopment
    Lots.update lotId, {$set: lotModifier}, (err, result) ->
      if err
        Entities.remove newEntityId, (removeErr, result) ->
          if removeErr
            df.reject(removeErr)
          else
            df.reject(err)
      else
        df.resolve(newEntityId)
  df.promise

####################################################################################################
# PROJECT SCHEMA DEFINITION
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
      lng:
        label: 'Longitude'
        type: Number
        decimal: true
        units: Units.deg
        desc: 'The longitude coordinate for this precinct'
      cam_elev:
        label: 'Camera Elevation'
        type: Number
        decimal: true
        units: Units.m
        desc: 'The starting elevation of the camera when viewing the project.'
  space:
    items:
      geom_2d:
        label: 'Geometry'
        type: String
        desc: '2D geometry of the precinct envelope.'
      area:
        label: 'Precinct Area'
        type: Number
        decimal: true
        desc: 'Total land area of the precinct.'
        units: Units.m2
# TODO(aramk) This would eventually be calculated using the area of geom_2d.
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
  project = if id then Projects.findOne(id) else Projects.getCurrent()
  location = project.parameters.location
  {latitude: location.lat, longitude: location.lng, elevation: location.cam_elev}

Projects.setLocationCoords = (id, location) ->
  id ?= Projects.getCurrentId()
  Projects.update id, $set:
    'parameters.location.lat': location.latitude
    'parameters.location.lng': location.longitude

