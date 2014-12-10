####################################################################################################
# SCHEMA OPTIONS
####################################################################################################

SimpleSchema.debug = true
SimpleSchema.extendOptions
# Optional extra fields.
# TODO(aramk) These are added globally, not just for typologies.
  desc: Match.Optional(String)
  units: Match.Optional(String)
# Used on reference fields containing IDs of models in the given collection type.
  collectionType: Match.Optional(String)
# An expression for calculating the value of the given field for the given model. These are output
# fields and do not appear in forms. The formula can be a string containing other field IDs prefixed
# with '$' (e.g. $occupants) which are resolved to the local value per model, or global parameters
# if no local equivalent is found. If the expression is a function, it is passed the current model
# and the field and should return the result.
  calc: Match.Optional(Match.Any)
# A map of class names to objects of properties. "defaultValues" specifies the default value for
# the given class.
  classes: Match.Optional(Object)

####################################################################################################
# COMMON SCHEMA AUXILIARY
####################################################################################################

# ^ and _ are converted to superscript and subscript in forms and reports.
Units =
  $m2: '$/m^2'
  $: '$'
  $day: '$/day'
  $kWh: '$/kWh'
  $MJ: '$/MJ'
  $kL: '$/kL'
  deg: 'degrees'
  GJyear: 'GJ/year'
  ha: 'ha'
  jobs: 'jobs'
  kgco2: 'kg CO_2-e'
  kgco2day: 'kg CO_2-e/day'
  kgco2kWh: 'kg CO_2-e/kWh'
  kgco2km: 'kg CO_2-e/km'
  kgco2m2: 'kg CO_2-e/m^2'
  kgco2year: 'kg CO_2-e/year'
  kW: 'kW'
  kWh: 'kWh'
  kWhday: 'kWh/day'
  kWhyear: 'kWh/year'
  kLyear: 'kL/year'
  kLm2year: 'kL/m^2/year'
  km: 'km'
  kmday: 'km/day'
  kmyear: 'km/year'
  lanes: 'lanes'
  Lsec: 'L/second'
  Lyear: 'L/year'
  m: 'm'
  m2: 'm^2'
  m2vehicle: 'm^2/vehicle'
  m2job: 'm^2/job'
  mm: 'mm'
  MLyear: 'ML/year'
  MJ: 'MJ'
  MJm2year: 'MJ/m^2/year'
  MJyear: 'MJ/year'
  people: 'people'
  spaces: 'spaces'
  spacesm: 'spaces/m'
  tripsday: 'trips/day'
  tripsyear: 'trips/year'
  vehicles: 'vehicles'
  years: 'years'

extendSchema = (orig, changes) -> _.extend({}, orig, changes)

# TODO(aramk) Can't use Strings or other utilities outside Meteor.startup since it's not loaded yet
toTitleCase = (str) ->
  parts = str.split(/\s+/)
  title = ''
  for part, i in parts
    if part != ''
      title += part.slice(0, 1).toUpperCase() + part.slice(1, part.length)
      if i != parts.length - 1 and parts[i + 1] != ''
        title += ' '
  title

autoLabel = (field, id) ->
  label = field.label
  if label?
    label
  else
    label = id.replace('_', '')
    toTitleCase(label)

createCategorySchemaObj = (cat, catId, args) ->
  catSchemaFields = {}
  hasRequiredField = false
  for itemId, item of cat.items
    if item.items?
      result = createCategorySchemaObj(item, itemId, args)
      if result.hasRequiredField
        hasRequiredField = true
      fieldSchema = result.schema
    else
      # Required fields must explicitly specify "optional" as false.
      fieldSchema = _.extend({optional: true}, args.itemDefaults, item)
      if fieldSchema.optional == false
        hasRequiredField = true
      autoLabel(fieldSchema, itemId)
      # If defaultValue is used, put it into "classes" to prevent SimpleSchema from storing this
      # value in the doc. We want to inherit this value at runtime for all classes, but not
      # persist it in multiple documents in case we want to change it later in the schema.
      defaultValue = fieldSchema.defaultValue
      if defaultValue?
        classes = fieldSchema.classes ?= {}
        allClassOptions = classes.ALL ?= {}
        if allClassOptions.defaultValue?
          throw new Error('Default value specified on field and in classOptions - only use one.')
        allClassOptions.defaultValue = defaultValue
        delete fieldSchema.defaultValue
    catSchemaFields[itemId] = fieldSchema
  catSchema = new SimpleSchema(catSchemaFields)
  catSchemaArgs = _.extend({
    # If a single field is required, the entire category is marked required. If no fields are
    # required, the category can be omitted.
    optional: !hasRequiredField
  }, args.categoryDefaults, cat, {type: catSchema})
  autoLabel(catSchemaArgs, catId)
  delete catSchemaArgs.items
  {hasRequiredField: hasRequiredField, schema: catSchemaArgs}

# Constructs a SimpleSchema which contains all categories and each category is it's own
# SimpleSchema.
createCategoriesSchema = (args) ->
  args ?= {}
  cats = args.categories
  unless cats
    throw new Error('No categories provided.')
  # For each category in the schema.
  catsFields = {}
  for catId, cat of cats
    result = createCategorySchemaObj(cat, catId, args)
    catsFields[catId] = result.schema
  new SimpleSchema(catsFields)

forEachCategoryField = (category, callback) ->
  for itemId, item of category.items
    if item.items?
      forEachCategoryField(item, callback)
    else
      callback(itemId, item, category)

forEachCategoriesField = (categories, callback) ->
  for catId, category of categories
    forEachCategoryField(category, callback)

####################################################################################################
# PROJECT SCHEMA DEFINITION
####################################################################################################

descSchema =
  label: 'Description'
  type: String
  optional: true

creatorSchema =
  label: 'Creator'
  type: String
  optional: true

VktRailTypes =
  rail0_400:
    label: '0 - 0.4 kms'
  rail400_800:
    label: '0.4 - 0.8 kms'
  rail800_1600:
    label: '0.8 - 1.6 kms'
  railgt_1600:
    label: '> 1.6 kms'

projectCategories =
  general:
    label: 'General'
    items:
      creator:
      # TODO(aramk) Integrate this with users.
        type: String
        desc: 'Creator of the project or precinct.'
        optional: false
  location:
    label: 'Location'
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
    label: 'Space'
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
  environment:
    label: 'Environment'
    items:
      climate_zn:
        label: 'Climate Zone'
        type: Number
        decimal: true
        desc: 'BOM climate zone number to determine available typologies.'
  operating_carbon:
    label: 'Operating Carbon'
    items:
      elec:
        label: 'Carbon per kWh - Electricity'
        type: Number
        decimal: true
        units: Units.kgco2kWh
        defaultValue: 0.92
      gas:
        label: 'Carbon per kWh - Gas'
        type: Number
        decimal: true
        units: Units.kgco2kWh
        defaultValue: 0.229
      vkt:
        label: 'Carbon per vehicle km travelled'
        type: Number
        units: Units.kgco2km
        defaultValue: 0.419
  renewable_energy:
    label: 'Renewable Energy'
    items:
      pv_output:
        desc: 'Output of PV per kW'
        units: Units.kWhday
        type: Number
        decimal: true
        defaultValue: 4.4
  utilities:
    label: 'Utilities'
    items:
      price_supply_elec:
        label: 'Electricity Supply Charge'
        type: Number
        decimal: true
        units: Units.$day
        defaultValue: 1.038
      price_usage_elec:
        label: 'Electricity Usage Price per kWh'
        type: Number
        decimal: true
        units: Units.$kWh
        defaultValue: 0.27
      price_supply_gas:
        label: 'Gas Supply Charge'
        type: Number
        decimal: true
        units: Units.$day
        defaultValue: 0.667
      price_usage_gas:
        label: 'Gas Usage Price'
        type: Number
        decimal: true
        units: '$/MJ'
        defaultValue: 0.024
      price_supply_water:
        label: 'Water Supply Charge'
        type: Number
        decimal: true
        units: Units.$day
        defaultValue: 0.298
      price_usage_water:
        label: 'Water Usage Price'
        type: Number
        decimal: true
        units: Units.$kL
        defaultValue: 0.25
  external_water:
    label: 'External Water'
    items:
      demand_lawn:
        label: 'Lawn Water Demand'
        type: Number
        decimal: true
        units: Units.kLm2year
        defaultValue: 1.0225
      demand_ap:
        label: 'Annual Plants Water Demand'
        type: Number
        decimal: true
        units: Units.kLm2year
        defaultValue: 1.1775
      demand_hp:
        label: 'Hardy Plants Water Demand'
        type: Number
        decimal: true
        units: Units.kLm2year
        defaultValue: 0.7275
  stormwater:
    label: 'Stormwater'
    items:
      runoff_roof:
        label: 'Roofed Area Run-Off Coefficient'
        type: Number
        decimal: true
        defaultValue: 1
      runoff_impervious:
        label: 'Impervious Area Run-Off Coefficient'
        type: Number
        decimal: true
        defaultValue: 0.9
      runoff_pervious:
        label: 'Pervious Area Run-Off Coefficient'
        type: Number
        decimal: true
        defaultValue: 0.16
      rainfall_intensity:
        label: 'Rainfall Intensity'
        type: Number
        decimal: true
        units: Units.mm
        defaultValue: 145
  financial:
    label: 'Financial'
    items:
      land:
        label: 'Land'
        items:
          # price_land:
          #   label: 'Land Value'
          #   type: Number
          #   desc: 'Land Value per Square Metre'
          #   units: Units.$m2
          #   defaultValue: 500
          price_land_r:
            label: 'Residential Land Value'
            type: Number
            desc: 'Land Value per Square Metre'
            units: Units.$m2
            defaultValue: 500
          price_land_c:
            label: 'Commercial Land Value'
            type: Number
            desc: 'Land Value per Square Metre'
            units: Units.$m2
            defaultValue: 600
          price_land_mu:
            label: 'Mixed Use Land Value'
            type: Number
            desc: 'Land Value per Square Metre'
            units: Units.$m2
            defaultValue: 550
          price_land_os:
            label: 'Open Space Land Value'
            type: Number
            desc: 'Land Value per Square Metre'
            units: Units.$m2
            defaultValue: 50
          price_land_pw:
            label: 'Pathway Land Value'
            type: Number
            desc: 'Land Value per Square Metre'
            units: Units.$m2
            defaultValue: 30
          price_land_i:
            label: 'Institutional Land Value'
            type: Number
            desc: 'Land Value per Square Metre'
            units: Units.$m2
            defaultValue: 150
      landscaping:
        label: 'Landscaping'
        items:
          price_lawn:
            label: 'Cost per Sqm - Lawn'
            type: Number
            decimal: true
            units: Units.$m2
            defaultValue: 40
          price_annu:
            label: 'Cost per Sqm - Annual Plants'
            type: Number
            decimal: true
            units: Units.$m2
            defaultValue: 40
          price_hardy:
            label: 'Cost per Sqm - Hardy Plants'
            type: Number
            decimal: true
            units: Units.$m2
            defaultValue: 50
          price_imper:
            label: 'Cost per Sqm - Impermeable'
            type: Number
            decimal: true
            units: Units.$m2
            defaultValue: 75
      residential:
        label: 'Residential'
        items:
          single_house_std:
            label: 'Single House - Standard'
            type: Number
            units: Units.$m2
            defaultValue: 1100
          single_house_hq:
            label: 'Single House - High Quality'
            type: Number
            units: Units.$m2
            defaultValue: 1950
          attached_house_std:
            label: 'Attached House - Standard'
            type: Number
            units: Units.$m2
            defaultValue: 1810
          attached_house_hq:
            label: 'Attached House - High Quality'
            type: Number
            units: Units.$m2
            defaultValue: 2060
          walkup_std:
            label: 'Walkup - Standard'
            type: Number
            units: Units.$m2
            defaultValue: 1785
          walkup_hq:
            label: 'Walkup - High Quality'
            type: Number
            units: Units.$m2
            defaultValue: 1985
          highrise_std:
            label: 'High Rise - Standard'
            type: Number
            units: Units.$m2
            defaultValue: 2090
          highrise_hq:
            label: 'High Rise - High Quality'
            type: Number
            units: Units.$m2
            defaultValue: 2815
      commercial:
        items:
          retail:
            items:
              local:
                label: 'Retail - Local Shop'
                type: Number
                units: Units.$m2
                defaultValue: 695
              shopping:
                label: 'Retail - Shopping Centre'
                type: Number
                units: Units.$m2
                defaultValue: 2125
          office:
            items:
              low_rise:
                label: 'Office - Low-rise Without Lifts'
                type: Number
                units: Units.$m2
                defaultValue: 1810
              med_rise:
                label: 'Office - Med-rise With Lifts'
                type: Number
                units: Units.$m2
                defaultValue: 2225
          hotel:
            items:
              three_star:
                label: 'Hotel - 3 Star'
                type: Number
                units: Units.$m2
                defaultValue: 3415
              five_star:
                label: 'Hotel - 5 Star'
                type: Number
                units: Units.$m2
                defaultValue: 4330
          supermarket:
            label: 'Supermarket'
            type: Number
            units: Units.$m2
            defaultValue: 1475
          restaurant:
            label: 'Restaurant'
            type: Number
            units: Units.$m2
            defaultValue: 2450
      institutional:
        items:
          school:
            items:
              primary:
                label: 'School - Primary'
                type: Number
                units: Units.$m2
                defaultValue: 1470
              secondary:
                label: 'School - Secondary'
                type: Number
                units: Units.$m2
                defaultValue: 1870
          tertiary:
            label: 'Tertiary'
            type: Number
            units: Units.$m2
            defaultValue: 2965
          hospital:
            items:
              single_storey:
                label: 'Hospital - Single-Storey'
                type: Number
                units: Units.$m2
                defaultValue: 3408
              multi_storey:
                label: 'Hospital - Multi-Storey'
                type: Number
                units: Units.$m2
                defaultValue: 4640
          public:
            items:
              low_rise_without_lifts:
                label: 'Public - Low-rise Without Lifts'
                type: Number
                units: Units.$m2
                defaultValue: 2296
              med_rise_with_lifts:
                label: 'Public - Med-rise With Lifts'
                type: Number
                units: Units.$m2
                defaultValue: 2878

      pathways:
        label: 'Pathways'
        items:
          roads:
            label: 'Roads'
            items:
              price_full_asphalt:
                label: 'Cost per Sqm - Full Depth Asphalt'
                type: Number
                units: Units.$m2
                defaultValue: 129
              price_asphalt_cement:
                label: 'Cost per Sqm - Asphalt Over Cement'
                type: Number
                units: Units.$m2
                defaultValue: 123
              price_granular_spray:
                label: 'Cost per Sqm - Granular with Spray Seal'
                type: Number
                units: Units.$m2
                defaultValue: 83
              price_granular_asphalt:
                label: 'Cost per Sqm - Granular with Asphalt'
                type: Number
                units: Units.$m2
                defaultValue: 85
              price_concrete_plain:
                label: 'Cost per Sqm - Plain Concrete'
                type: Number
                units: Units.$m2
                defaultValue: 96
              price_concrete_reinforced:
                label: 'Cost per Sqm - Reinforced Concrete'
                type: Number
                units: Units.$m2
                defaultValue: 116
          footpaths:
            label: 'Footpaths'
            items:
              price_concrete:
                label: 'Cost per Sqm - Concrete'
                type: Number
                units: Units.$m2
                defaultValue: 42
              price_block_paved:
                label: 'Cost per Sqm - Block Paved'
                type: Number
                units: Units.$m2
                defaultValue: 64
          bicycle_paths:
            label: 'Bicycle Paths'
            items:
              price_asphalt:
                label: 'Cost per Sqm - Asphalt'
                type: Number
                units: Units.$m2
                defaultValue: 41
              price_concrete:
                label: 'Cost per Sqm - Concrete'
                type: Number
                units: Units.$m2
                defaultValue: 52
          all:
            label: 'All'
            items:
              price_verge:
                label: 'Cost per Sqm - Verge'
                type: Number
                units: Units.$m2
                defaultValue: 20
      parking:
        label: 'Parking'
        items:
          cost_ug_park:
            label: 'Cost per Underground Parking Space'
            type: Number
            units: Units.$
            defaultValue: 48400
  embodied_carbon:
    label: 'Embodied Carbon'
    items:
      landscaping:
        label: 'Landscaping'
        items:
          greenspace:
            label: 'Greenspace'
            type: Number
            decimal: true
            units: Units.kgco2m2
            defaultValue: -20
          impermeable:
            label: 'Impermeable'
            type: Number
            decimal: true
            units: Units.kgco2m2
            defaultValue: 2.2586
      pathways:
        label: 'Pathways'
        items:
          roads:
            label: 'Roads'
            items:
              full_asphalt:
                label: 'Full Depth Asphalt'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 36.04
              deep_asphalt:
                label: 'Deep Strength Asphalt'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 33.8
              granular_spray:
                label: 'Granular with Spray Seal'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 11.35
              granular_asphalt:
                label: 'Granular with Asphalt'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 12.07
              concrete_plain:
                label: 'Plain Concrete'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 51.33
              concrete_reinforced:
                label: 'Reinforced Concrete'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 53.51
          footpaths:
            label: 'Footpaths'
            items:
              concrete:
                label: 'Concrete'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 26.38
              block_paved:
                label: 'Block Paved'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 7.48
          bicycle_paths:
            label: 'Bicycle Paths'
            items:
              asphalt:
                label: 'Asphalt'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 4.85
              concrete:
                label: 'Concrete'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: 45.12
          all:
            label: 'All'
            items:
              verge:
                label: 'Verge'
                type: Number
                decimal: true
                units: Units.kgco2m2
                defaultValue: -20
  energy:
    label: 'Energy'
    items:
      fitout:
        label: 'Fitout'
        items:
          en_elec_oven:
            label: 'Energy - Electric Oven and Cooktop'
            type: Number
            units: Units.MJ
            defaultValue: 1956
          en_gas_oven:
            label: 'Energy - Gas Oven and Cooktop'
            type: Number
            units: Units.MJ
            defaultValue: 3366
          en_basic_avg_app:
            label: 'Energy - Basic Avg Perfomance Appliances'
            type: Number
            units: Units.MJ
            defaultValue: 9749
          en_basic_hp_app:
            label: 'Energy - Basic High Performance Appliances'
            type: Number
            units: Units.MJ
            defaultValue: 6998
          en_aff_avg_app:
            label: 'Energy - Affluenza Avg Performance Appliances'
            type: Number
            units: Units.MJ
            defaultValue: 12442
          en_aff_hp_app:
            label: 'Energy - Affluenza High Perfomance Appliances'
            type: Number
            units: Units.MJ
            defaultValue: 10951
  parking:
    label: 'Parking'
    items:
      prk_area_veh:
        label: 'Parking Area per Vehicle'
        type: Number
        units: Units.m2vehicle
        defaultValue: 23
  transport:
    label: 'Transport'
    items:
      trips:
        label: 'Daily Trips per Dwelling'
        type: Number
        decimal: true
        units: 'trips/dwelling'
        defaultValue: 10.7
      age:
        label: 'Mean Age'
        type: Number
        decimal: true
        units: Units.years
        defaultValue: 38
      gender:
        label: 'Share Female Residents'
        type: Number
        decimal: true
        defaultValue: 0.52
      hhsize:
        label: 'Household Size'
        type: Number
        decimal: true
        units: Units.people
        defaultValue: 2.6
      totalvehs:
        label: 'Vehicles per Household'
        type: Number
        decimal: true
        units: Units.vehicles
        defaultValue: 1.8
      hhinc_grp:
        label: 'Household Income Group'
        type: Number
        decimal: true
        defaultValue: 3.3
      distctr:
        label: 'Distance to Activity Centre'
        type: Number
        decimal: true
        units: Units.km
        defaultValue: 6.3
      railprox:
        label: 'Proximity to Rail'
        type: String
        units: Units.km
        defaultValue: 'railgt_1600'
        allowedValues: Object.keys(VktRailTypes)
      distbus:
        label: 'Distance to Bus Stop'
        type: Number
        decimal: true
        units: Units.km
        defaultValue: 0.4
      lum_index:
        label: 'LUM Index'
        type: Number
        decimal: true
        defaultValue: 0.38
      density:
        label: 'Density'
        type: Number
        decimal: true
        defaultValue: 21.8
      towork:
        label: 'Share of Work Trips'
        type: Number
        decimal: true
        defaultValue: 0.22

ProjectParametersSchema = createCategoriesSchema
  categories: projectCategories

ProjectSchema = new SimpleSchema
  name:
    label: 'Name'
    type: String
    index: true
    unique: true
  desc: descSchema
  creator: creatorSchema
  parameters:
    label: 'Parameters'
    type: ProjectParametersSchema
    defaultValue: {}

@Projects = new Meteor.Collection 'projects', schema: ProjectSchema
Projects.attachSchema(ProjectSchema)
Projects.allow(Collections.allowAll())

hasSession = typeof Session != 'undefined'
Projects.setCurrentId = (id) -> Session.set('projectId', id) if hasSession
Projects.getCurrent = ->
  id = Projects.getCurrentId()
  Projects.findOne(id)
Projects.getCurrentId = -> Session.get('projectId') if hasSession

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
  df = Q.defer()
  id ?= Projects.getCurrentId()
  Projects.update id, $set: {
    'parameters.location.lat': location.latitude
    'parameters.location.lng': location.longitude
  }, (err, result) -> if err then df.reject(err) else df.resolve(result)
  df.promise

Projects.getDefaultParameterValues = _.memoize ->
  values = {}
  SchemaUtils.forEachFieldSchema ProjectParametersSchema, (fieldSchema, paramId) ->
    # Default value is stored in the "classes" object to avoid being used by SimpleSchema.
    defaultValue = fieldSchema.classes?.ALL?.defaultValue
    if defaultValue?
      values[paramId] = defaultValue
  Typologies.unflattenParameters(values, false)

Projects.mergeDefaults = (model) ->
  defaults = Projects.getDefaultParameterValues()
  mergeDefaultParameters(model, defaults)

####################################################################################################
# TYPOLOGY SCHEMA DECLARATION
####################################################################################################

TypologyClasses =
  RESIDENTIAL:
    name: 'Residential'
    color: '#009cff' # Blue
    abbr: 'r'
  COMMERCIAL:
    name: 'Commercial'
    color: 'red'
    abbr: 'c'
  MIXED_USE:
    name: 'Mixed Use'
    color: '#c000ff' # Purple
    abbr: 'mu'
  OPEN_SPACE:
    name: 'Open Space'
    color: '#7ed700' # Green
    abbr: 'os'
    displayMode: false
  PATHWAY:
    name: 'Pathway'
    color: 'black'
    abbr: 'pw'
    displayMode: 'line'
  INSTITUTIONAL:
    name: 'Institutional'
    color: 'orange'
    abbr: 'i'

BuildingClasses =
  RESIDENTIAL: {}
  COMMERCIAL: {}
  MIXED_USE: {}
  INSTITUTIONAL: {}

extendClassMap = (args, map) -> Setter.merge({}, map, args)
extendBuildingClasses = (args) -> extendClassMap(args, BuildingClasses)
extendClassesWithDefault = (classArgs, defaultValue) ->
  _.each classArgs, (args, typologyClass) ->
    args.defaultValue = defaultValue
  classArgs

LandClasses = extendClassMap
  OPEN_SPACE: {}

extendLandClasses = (args) -> extendClassMap(args, LandClasses)

classHasIntensity = (typologyClass) ->
  typologyClass == 'COMMERCIAL' || typologyClass == 'INSTITUTIONAL'

ClassNames = Object.keys(TypologyClasses)

TypologyTypes = ['Basic', 'Efficient', 'Advanced']
ResidentialSubclasses = ['Single House', 'Attached House', 'Walkup', 'High Rise']
CommercialSubclasses = ['Retail', 'Office', 'Hotel', 'Supermarket', 'Restaurant']
InstitutionalSubclasses = ['School', 'Tertiary', 'Hospital', 'Public']
PathwaySubclasses = ['Freeway', 'Highway', 'Street', 'Footpath', 'Bicycle Path']
EnergySources = ['Electricity', 'Gas']

ResidentialBuildTypes =
  'Standard Quality Build':
    'Single House': 'single_house_std'
    'Attached House': 'attached_house_std'
    'Walkup': 'walkup_std'
    'High Rise': 'highrise_std'
  'High Quality Build':
    'Single House': 'single_house_hq'
    'Attached House': 'attached_house_hq'
    'Walkup': 'walkup_hq'
    'High Rise': 'highrise_hq'
CommercialBuildTypes =
  'Retail':
    'Local Shop': 'retail.local'
    'Shopping Centre': 'retail.shopping'
  'Office':
    'Low-rise Without Lifts': 'office.low_rise'
    'Med-rise With Lifts': 'office.med_rise'
  'Hotel':
    '3 Star': 'hotel.three_star'
    '5 Star': 'hotel.five_star'
  'Supermarket':
    'Supermarket': 'supermarket'
  'Restaurant':
    'Restaurant': 'restaurant'
InstitutionalBuildTypes =
  'School':
    'Primary': 'school.primary'
    'Secondary': 'school.secondary'
  'Tertiary':
    'Tertiary': 'school.tertiary'
  'Hospital':
    'Single-Storey': 'hospital.single_storey'
    'Multi-Storey': 'hospital.multi_storey'
  'Public':
    'Low-rise Without Lifts': 'public.low_rise_without_lifts'
    'Med-rise With Lifts': 'public.med_rise_with_lifts'

createBuildTypeClassOptions = (buildTypesMap, prefix) ->
  options =
    defaultValue: 'Custom'
    allowedValues: (args) ->
      values = buildTypesMap[args.subclass]
      if values then Object.keys(values) else []
    getCostParamId: (args) ->
      'financial.' + prefix + '.' + buildTypesMap[args.subclass]?[args.value]

# Appliance type to the project parameter storing its energy usage.
ApplianceTypes =
  'Basic - Avg Performance': 'en_basic_avg_app'
  'Basic - High Performance': 'en_basic_hp_app'
  'Affluenza - Avg Performance': 'en_aff_avg_app'
  'Affluenza - High Performance': 'en_aff_hp_app'
WaterDemandSources = ['Potable', 'Bore', 'Rainwater Tank', 'On-Site Treated', 'Greywater']
RoadMaterialTypes =
  'Full Depth Asphalt': 'full_asphalt'
  'Deep Strength Asphalt': 'deep_asphalt'
  'Granular with Spray Seal': 'granular_spray'
  'Granular with Asphalt': 'granular_asphalt'
  'Plain Concrete': 'concrete_plain'
  'Reinforced Concrete': 'concrete_reinforced'
FootpathMaterialTypes =
  'Concrete': 'concrete'
  'Block Paved': 'block_paved'
BicyclePathMaterialTypes =
  'Asphalt': 'asphalt'
  'Concrete': 'concrete'

TransportModelParameters =
  intercept: 1.638503
  coefficients:
    hhsize: 0.137197
    totalvehs: 1.234835
    hhinc_grp: 0.449265
    distctr: 0.060162
    distbus: 0.416703
    lum_index: -0.482782
    density: -0.008418
  rail:
    rail0_400: -1.17115
    rail400_800: -0.533986
    rail800_1600: -0.355058
    railgt_1600: 0
TransportModeShareModel =
  TRANSIT:
    intercept: 0.52540652
    coefficients:
      age: -0.03730417
      density: 0.00211621
      distbus: -0.33821962
      distctr: -0.02444697
      gender: 0.12682523
      hhinc_grp: -0.07678141
      lum_index: 0.29376731
      totalvehs: -0.72141909
      towork: 0.90955219
    rail:
      rail0_400: 0.90965021
      rail400_800: 0.39663054
      rail800_1600: 0.2272072
      railgt_1600: 0
  VEHPASS:
    intercept: 2.35196487
    coefficients:
      age: -0.0644734
      density: -0.00296777
      distbus: 0.01352963
      distctr: -0.0026131
      gender: 0.35736189
      hhinc_grp: -0.07473318
      lum_index: 0.00570112
      totalvehs: -0.18236871
      towork: -1.99704375
    rail:
      rail0_400: 0.03718638
      rail400_800: -0.01300623
      rail800_1600: 0.00799577
      railgt_1600: 0
  ACTIVE:
    intercept: 0.69033114
    coefficients:
      age: -0.02952043
      density: 0.01042317
      distbus: -0.39800579
      distctr: 0.00731302
      gender: 0.04724299
      hhinc_grp: -0.07740797
      lum_index: 0.2056736
      totalvehs: -0.51259628
      towork: -1.29622958
    rail:
      rail0_400: 0.90613405
      rail400_800: 0.60263267
      rail800_1600: 0.3058829
      railgt_1600: 0

# Common field schemas shared across collection schemas.

classSchema =
  type: String
  desc: 'Major class or land use category of the precinct object.'
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
  collectionType: 'Projects'

calcArea = (id) ->
  feature = AtlasManager.getEntity(id)
  if feature
    target = feature.getForm('footprint')
    unless target
      target = feature.getForm('mesh')
    unless target
      throw new Error('GeoEntity was found but no footprint or mesh exists - cannot calculate ' +
        'area.')
    target.getArea()
  else
    throw new Error('GeoEntity not found - cannot calculate area.')

calcLength = (id) ->
  feature = AtlasManager.getEntity(id)
  line = feature.getForm('line')
  unless line
    throw new Error('Cannot calculate length of non-line GeoEntity with ID ' + id)
  line.getLength()

areaSchema =
  label: 'Area'
  type: Number
  desc: 'Area of the land parcel.'
  decimal: true
  units: Units.m2
  calc: -> calcArea(@model._id)

# NOTE: energyParamId expected to be in MJ.
calcEnergyC02 = (sourceParamId, energyParamId) ->
  src = @param(sourceParamId)
  en = @param(energyParamId)
  return null unless src? and en?
  if src == 'Electricity'
    en * @KWH_TO_MJ(@param('operating_carbon.elec'))
  else if src == 'Gas'
    en * @KWH_TO_MJ(@param('operating_carbon.gas'))

calcEnergyCost = (source, suffix) ->
  supply_price = @param('utilities.price_supply_' + suffix)
  usage_price = @param('utilities.price_usage_' + suffix)
  if source == 'Gas'
    usage_price = @KWH_TO_MJ(usage_price)
  src_heat = @param('energy_demand.src_heat')
  src_hwat = @param('energy_demand.src_hwat')
  src_cook = @param('energy_demand.src_cook')
  en_heat = @param('energy_demand.en_heat')
  en_hwat = @param('energy_demand.en_hwat')
  en_cook = @param('energy_demand.en_cook')
  en_app = @param('energy_demand.en_app')
  en_light = @param('energy_demand.en_light')
  pv_output = @param('renewable_energy.pv_output')
  size_pv = @param('energy_demand.size_pv')
  usage_cost = 0
  if src_heat == source
    usage_cost += en_heat * usage_price
  if src_hwat == source
    usage_cost += en_hwat * 1000 * usage_price
  if src_cook == source
    usage_cost += en_cook * usage_price
  if source == 'Electricity'
    usage_cost += en_app * usage_price
    usage_cost += en_light * usage_price
    usage_cost -= 365 * pv_output * size_pv * usage_price
  365 * supply_price + usage_cost

calcEnergyWithIntensityCost = (suffix, shortSuffix) ->
  supply_price = @param('utilities.price_supply_' + suffix)
  usage_price = @KWH_TO_MJ(@param('utilities.price_usage_' + suffix))
  usage_cost = @param('energy_demand.en_use_' + shortSuffix) * usage_price
  365 * supply_price + usage_cost

calcLandPrice = ->
  typologyClass = Entities.getTypologyClass(@model._id)
  abbr = TypologyClasses[typologyClass].abbr
  @param('financial.land.price_land_' + abbr)

calcTransportLinearRegression = (params) ->
  value = params.intercept
  _.each params.coefficients, (coeffValue, field) =>
    value += coeffValue * @param('transport.' + field)
  railprox = @param('transport.railprox')
  value += params.rail[railprox]
  value

typologyCategories =
  general:
    label: 'General'
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
        desc: 'Typology within a class.'
        classes:
          RESIDENTIAL: {allowedValues: ResidentialSubclasses, optional: false}
          COMMERCIAL: {allowedValues: CommercialSubclasses, optional: false}
          INSTITUTIONAL: {allowedValues: InstitutionalSubclasses, optional: false}
          PATHWAY: {allowedValues: PathwaySubclasses, optional: false}
      climate_zn:
        desc: 'BOM climate zone number.'
        label: 'Climate Zone'
        type: Number
        classes:
          RESIDENTIAL: {}
      type:
        type: String
        desc: 'Version of the subclass.'
        allowedValues: TypologyTypes
        classes:
          RESIDENTIAL: {}
  space:
    label: 'Space'
    items:
      geom_2d:
        label: '2D Geometry'
        type: String
        desc: '2D footprint geometry of the typology.'
        classes: extendBuildingClasses
          RESIDENTIAL: {optional: false}
          COMMERCIAL: {optional: false}
          INSTITUTIONAL: {optional: false}
          # Pathway typologies don't have geometry - it is defined in the entities - so this is
          # optional.
          PATHWAY: {}
      geom_3d:
        label: '3D Geometry'
        type: String
        desc: '3D mesh representing the typology.'
        classes: BuildingClasses
      geom_2d_filename:
        label: '2D Geometry Filename'
        type: String
        desc: 'The name of the file representing the 2D geometry.'
      geom_3d_filename:
        label: '3D Geometry Filename'
        type: String
        desc: 'The name of the file representing the 3D geometry.'
      lotsize: extendSchema(areaSchema, {
        label: 'Lot Size'
        calc: ->
          # If the model is a typology, it doesn't have a lot yet, so no lotsize.
          id = @model._id
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
        calc: ->
          id = @model._id
          entity = Entities.findOne(id)
          if entity
            typology = Typologies.findOne(entity.typology)
            typologyClass = SchemaUtils.getParameterValue(typology, 'general.class')
            if typologyClass == 'OPEN_SPACE'
              # Open space typologies don't have geometries since they occupy the Lot itself, so
              # they don't have any FPA.
              return 0
          calcArea(id)
      })
      gfa:
        label: 'Gross Floor Area'
        desc: 'Gross floor area of all the rooms in the typology.'
        type: Number
        decimal: true
        units: Units.m2
        classes: BuildingClasses
      cfa:
        label: 'Conditioned Floor Area'
        desc: 'Total conditioned area of the typology.'
        type: Number
        decimal: true
        units: Units.m2
        classes: BuildingClasses
      storeys:
        label: 'Storeys'
        desc: 'Number of floors/storeys in the typology.'
        type: Number
        units: 'Floors'
        classes: BuildingClasses
      height: extendSchema(heightSchema, {
        classes: BuildingClasses
        })
      length:
        label: 'Total Path Length'
        desc: 'Total length of drawn pathway'
        type: Number
        decimal: true
        units: Units.m
        calc: -> calcLength(@model._id)
      width:
        label: 'Total Path Width'
        desc: 'Total width of drawn pathway'
        type: Number
        decimal: true
        units: Units.m
        calc: ->
          sum = 0
          _.each ['rd', 'prk', 'fp', 'bp', 've'], (prefix) =>
            sum += @param('composition.' + prefix + '_lanes') * @param('composition.' + prefix + '_width')
          sum
        classes:
          PATHWAY: {}
      area:
        label: 'Total Path Area'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$space.width * $space.length'
        classes:
          PATHWAY: {}
      plot_ratio:
        label: 'Plot Ratio'
        desc: 'The building footprint area divided by the lot size.'
        type: Number
        calc: '$space.gfa / $space.lotsize'
      occupants:
        label: 'No. Occupants'
        desc: 'Number of occupants in the typology.'
        type: Number
        units: 'Persons'
        classes:
          RESIDENTIAL: {}
      job_intensity:
        desc: 'Number of jobs per square metre of commercial floorspace.'
        label: 'Job Intensity'
        type: Number
        decimal: true
        units: Units.m2job
        classes:
          COMMERCIAL: {defaultValue: 20}
          INSTITUTIONAL: {defaultValue: 20}
      jobs:
        desc: 'Number of jobs in the commerical building.'
        label: 'Number of Jobs'
        type: Number
        units: Units.jobs
        calc: '$space.gfa / $space.job_intensity'
      num_0br:
        label: 'Dwellings - Studio'
        desc: 'Number of studio units in the typology.'
        type: Number
        units: 'Dwellings'
        classes:
          RESIDENTIAL: {}
      num_1br:
        label: 'Dwellings - 1 Bedroom'
        desc: 'Number of 1 bedroom units in the typology.'
        type: Number
        units: 'Dwellings'
        classes:
          RESIDENTIAL: {}
      num_2br:
        label: 'Dwellings - 2 Bedroom'
        desc: 'Number of 2 bedroom units in the typology.'
        type: Number
        units: 'Dwellings'
        classes:
          RESIDENTIAL: {}
      num_3plus:
        label: 'Dwellings - 3 Bedroom Plus'
        desc: 'Number of 3 bedroom units in the typology.'
        type: Number
        units: 'Dwellings'
        classes:
          RESIDENTIAL: {}
      dwell_tot:
        label: 'Dwellings - Total'
        desc: 'Number of total dwellings in the typology.'
        type: Number
        units: 'Dwellings'
        calc: '$space.num_0br + $space.num_1br + $space.num_2br + $space.num_3plus'
      dwell_dens:
        label: 'Dwelling - Density'
        desc: 'Total number of dwellings divided by the lot size.'
        type: Number
        decimal: true
        units: 'Dwellings/' + Units.ha
        calc: '$space.dwell_tot / $space.lotsize * 10000'
      prpn_lawn:
        label: 'Proportion Extra Land - Lawn'
        desc: 'Proportion of extra land covered by lawn.'
        type: Number
        decimal: true
        classes:
          RESIDENTIAL: {defaultValue: 0.15}
          COMMERCIAL: {defaultValue: 0.1}
          MIXED_USE: {defaultValue: 0.15}
          OPEN_SPACE: {}
          INSTITUTIONAL: {defaultValue: 0.1}
      prpn_annu:
        label: 'Proportion Extra Land - Annual Plants'
        desc: 'Proportion of extra land covered by annual plants, such as flowers and veggies.'
        type: Number
        decimal: true
        classes: extendLandClasses
          RESIDENTIAL: {defaultValue: 0.1}
          COMMERCIAL: {defaultValue: 0}
          MIXED_USE: {defaultValue: 0.1}
          OPEN_SPACE: {}
          INSTITUTIONAL: {defaultValue: 0}
      prpn_hardy:
        label: 'Proportion Extra Land - Hardy Plants'
        desc: 'Proportion of extra land covered by hardy or waterwise plants.'
        type: Number
        decimal: true
        classes: extendLandClasses
          RESIDENTIAL: {defaultValue: 0.35}
          COMMERCIAL: {defaultValue: 0}
          MIXED_USE: {defaultValue: 0.15}
          OPEN_SPACE: {}
          INSTITUTIONAL: {defaultValue: 0}
      prpn_imper:
        label: 'Proportion Extra Land - Impermeable'
        desc: 'Proportion of extra land covered by pavement or another impermeable surface.'
        type: Number
        decimal: true
        classes: extendLandClasses
          RESIDENTIAL: {defaultValue: 0.4}
          COMMERCIAL: {defaultValue: 0.9}
          MIXED_USE: {defaultValue: 0.6}
          OPEN_SPACE: {}
          INSTITUTIONAL: {defaultValue: 0.9}
      ext_land_l:
        label: 'Extra Land - Lawn'
        desc: 'Area of extra land covered by lawn.'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$space.extland * $space.prpn_lawn'
      ext_land_a:
        label: 'Extra Land - Annual Plants'
        desc: 'Area of extra land covered by annual plants, such as flowers and veggies.'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$space.extland * $space.prpn_annu'
      ext_land_h:
        label: 'Extra Land - Hardy Plants'
        desc: 'Area of extra land covered by hardy or waterwise plants.'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$space.extland * $space.prpn_hardy'
      ext_land_i:
        label: 'Extra Land - Impermeable'
        desc: 'Area of extra land covered by pavement or another impermeable surface.'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$space.extland * $space.prpn_imper'
  energy_demand:
    label: 'Energy Demand'
    items:
      en_heat:
        label: 'Heating'
        desc: 'Energy required for heating the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        classes:
          RESIDENTIAL: {}
      src_heat:
        label: 'Heating Source'
        desc: 'Energy source in the typology used for heating.'
        type: String
        allowedValues: EnergySources
        classes:
          RESIDENTIAL:
            defaultValue: 'Gas'
      en_cool:
        label: 'Cooling'
        desc: 'Energy required for cooling the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        classes:
          RESIDENTIAL: {}
      en_light:
        label: 'Lighting'
        desc: 'Energy required for lighting the typology.'
        type: Number
        decimal: true
        units: Units.kWhyear
        classes:
          RESIDENTIAL: {}
      en_hwat:
        label: 'Hot Water'
        desc: 'Energy required for hot water heating in the typology.'
        type: Number
        decimal: true
        units: Units.GJyear
        classes:
          RESIDENTIAL: {}
      src_hwat:
        label: 'Hot Water Source'
        desc: 'Energy source in the typology used for hot water heating. Used to calculated CO2-e.'
        type: String
        allowedValues: EnergySources
        classes:
          RESIDENTIAL:
            defaultValue: 'Electricity'
      en_cook:
        label: 'Cooktop and Oven'
        desc: 'Energy required for cooking in the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: 'IF($energy_demand.src_cook=="Electricity", $energy.fitout.en_elec_oven, IF($energy_demand.src_cook=="Gas", $energy.fitout.en_gas_oven)) * ($space.num_0br + $space.num_1br + $space.num_2br + $space.num_3plus)'
        classes:
          RESIDENTIAL: {}
    # TODO(aramk) Default value should be based on src_cook.
      src_cook:
        label: 'Cooktop and Oven Source'
        desc: 'Energy source in the typology used for cooking. Used to calculate CO2-e.'
        type: String
        allowedValues: EnergySources
        classes:
          RESIDENTIAL:
            defaultValue: 'Electricity'
      en_app:
        label: 'Appliances'
        desc: 'Energy required for powering appliances in the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
#        calc: 'IF($energy_demand.type_app=="Basic - Avg Performance", $energy.fitout.en_basic_avg_app, IF($energy_demand.type_app=="Basic - High Performance", $energy.fitout.en_basic_hp_app, IF($energy_demand.type_app=="Affluenza - Avg Performance", $energy.fitout.en_aff_avg_app, IF($energy_demand.type_app=="Affluenza - High Performance", $energy.fitout.en_aff_hp_app)))) * ($space.num_0br + $space.num_1br + $space.num_2br + $space.num_3plus)'
        calc: ->
          type_app = @param('energy_demand.type_app')
          type_en = @param('energy.fitout.' + ApplianceTypes[type_app])
          rooms = @calc('$space.num_0br + $space.num_1br + $space.num_2br + $space.num_3plus')
          type_en * rooms
      type_app:
        label: 'Appliances Source'
        desc: 'Type of appliance fit out.'
        type: String
        allowedValues: Object.keys(ApplianceTypes),
        classes:
          RESIDENTIAL:
            defaultValue: 'Basic - Avg Performance'
      en_int_e:
        desc: 'Electricity energy use intensity of the typology.'
        label: 'Energy Use Intensity - Electricity'
        type: Number
        decimal: true
        units: Units.MJm2year
        classes:
          COMMERCIAL:
            subclasses:
              'Retail': {defaultValue: 1140}
              'Office': {defaultValue: 651}
              'Hotel': {defaultValue: 909}
              'Supermarket': {defaultValue: 3206}
              'Restaurant': {defaultValue: 4878}
          INSTITUTIONAL:
            subclasses:
              'School': {defaultValue: 156}
              'Tertiary': {defaultValue: 626}
              'Hospital': {defaultValue: 703.5}
              'Public': {defaultValue: 806}
      en_use_e:
        desc: 'Electricity energy use of the typology.'
        label: 'Energy Use - Electricity'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: '$energy_demand.en_int_e * $space.gfa'
      en_int_g:
        desc: 'Gas energy use intensity of the typology.'
        label: 'Energy Use Intensity - Gas'
        type: Number
        decimal: true
        units: Units.MJm2year
        classes:
          COMMERCIAL:
            subclasses:
              'Retail': {defaultValue: 465}
              'Office': {defaultValue: 266}
              'Hotel': {defaultValue: 511}
              'Supermarket': {defaultValue: 169}
              'Restaurant': {defaultValue: 1540}
          INSTITUTIONAL:
            subclasses:
              'School': {defaultValue: 17.9}
              'Tertiary': {defaultValue: 284}
              'Hospital': {defaultValue: 689.5}
              'Public': {defaultValue: 202}
      en_use_g:
        desc: 'Gas energy use of the typology.'
        label: 'Energy Use - Gas'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: '$energy_demand.en_int_g * $space.gfa'
      size_pv:
        label: 'PV System Size'
        desc: 'PV system size fitted on the typology.'
        type: Number
        decimal: true
        units: Units.kW
        classes: extendClassesWithDefault(extendBuildingClasses(), 0)
      en_pv:
        label: 'PV Energy Generation'
        desc: 'Energy generated by the fitted PV system.'
        type: Number
        decimal: true
        units: Units.kWh
        calc: '$energy_demand.size_pv * $renewable_energy.pv_output * 365'
      en_total:
        label: 'Total Operating'
        desc: 'Total operating energy from all energy uses.'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: ->
          if classHasIntensity(Entities.getTypologyClass(@model._id))
            @calc('$energy_demand.en_use_e + $energy_demand.en_use_g - (KWH_TO_MJ($energy_demand.size_pv * $renewable_energy.pv_output * 365))')
          else
            @calc('$energy_demand.en_app + $energy_demand.en_cook + ($energy_demand.en_hwat * 1000) + KWH_TO_MJ($energy_demand.en_light) + $energy_demand.en_cool + $energy_demand.en_heat - KWH_TO_MJ($energy_demand.en_pv)')
  embodied_carbon:
    label: 'Embodied Carbon'
    items:
      e_co2_green:
        label: 'Greenspace'
        desc: 'CO2 embodied in the greenspace portion of external land.'
        type: Number
        units: Units.kgco2
        calc: '($space.ext_land_l + $space.ext_land_a + $space.ext_land_h) * $embodied_carbon.landscaping.greenspace'
      e_co2_imp:
        label: 'Impervious'
        desc: 'CO2 embodied in the impervious portion of external land.'
        type: Number
        units: Units.kgco2
        calc: '$space.ext_land_i * $embodied_carbon.landscaping.impermeable'
      e_co2_emb:
        label: 'Total External Embodied'
        desc: 'CO2 embodied in the external impermeable surfaces.'
        type: Number
        units: Units.kgco2
        calc: '$embodied_carbon.e_co2_green + $embodied_carbon.e_co2_imp'
      i_co2_emb_intensity:
        label: 'CO2 - Internal Embodied Intensity'
        desc: 'CO2 per square metre embodied in the building.'
        type: Number
        units: Units.kgco2m2
        classes:
          COMMERCIAL:
            subclasses:
              'Retail': {defaultValue: 375}
              'Office': {defaultValue: 450}
              'Hotel': {defaultValue: 480}
              'Supermarket': {defaultValue: 375}
              'Restaurant': {defaultValue: 350}
          INSTITUTIONAL:
            subclasses:
              'School': {defaultValue: 475}
              'Tertiary': {defaultValue: 475}
              'Hospital': {defaultValue: 380}
              'Public': {defaultValue: 375}
      i_co2_emb:
        label: 'Internal Embodied'
        desc: 'CO2 embodied in the materials of the typology.'
        type: Number
        units: Units.kgco2
        classes:
          RESIDENTIAL: {}
      t_co2_emb:
        label: 'Total Embodied'
        desc: 'Total CO2 embodied in the property.'
        type: Number
        units: Units.kgco2
        calc: ->
          if classHasIntensity(Entities.getTypologyClass(@model._id))
            i_co2_emb = @calc('$embodied_carbon.i_co2_emb_intensity * $space.gfa')
          else
            i_co2_emb = @param('embodied_carbon.i_co2_emb')
          @param('embodied_carbon.e_co2_emb') + i_co2_emb
      pathways:
        label: 'Pathways'
        items:
          co2_rd:
            desc: 'Carbon embodied in the road surface.'
            label: 'Road'
            type: Number
            decimal: true
            units: Units.kgco2
            calc: ->
              area = @param('composition.rd_area')
              mat = @param('composition.rd_mat')
              embodied_carbon = @param('embodied_carbon.pathways.roads.' + RoadMaterialTypes[mat])
              area * embodied_carbon
          co2_prk:
            desc: 'Carbon embodied in the parking surface.'
            label: 'Parking'
            type: Number
            decimal: true
            units: Units.kgco2
            calc: ->
              area = @param('composition.prk_area')
              mat = @param('composition.prk_mat')
              embodied_carbon = @param('embodied_carbon.pathways.roads.' + RoadMaterialTypes[mat])
              area * embodied_carbon
          co2_fp:
            desc: 'Carbon embodied in the footpath surface.'
            label: 'Footpath'
            type: Number
            decimal: true
            units: Units.kgco2
            calc: ->
              area = @param('composition.fp_area')
              mat = @param('composition.fp_mat')
              embodied_carbon = @param('embodied_carbon.pathways.footpaths.' +
                FootpathMaterialTypes[mat])
              area * embodied_carbon
          co2_bp:
            desc: 'Carbon embodied in the bicycle path surface.'
            label: 'Bicycle Path'
            type: Number
            decimal: true
            units: Units.kgco2
            calc: ->
              area = @param('composition.bp_area')
              mat = @param('composition.bp_mat')
              embodied_carbon = @param('embodied_carbon.pathways.bicycle_paths.' +
                BicyclePathMaterialTypes[mat])
              area * embodied_carbon
          co2_ve:
            desc: 'Carbon embodied in the verge surface.'
            label: 'Verge'
            type: Number
            decimal: true
            units: Units.kgco2
            calc: '$composition.ve_area * $embodied_carbon.pathways.all.verge'
          co2_embod:
            desc: 'Total embodied carbon of the drawn pathway.'
            label: 'Total Carbon'
            type: Number
            decimal: true
            units: Units.kgco2
            calc: ->
              sum = 0
              _.each ['rd', 'prk', 'fp',  'bp', 've'], (paramId) =>
                sum += @param('embodied_carbon.pathways.co2_' + paramId)
              sum
  operating_carbon:
    label: 'Operating Carbon'
    items:
      co2_heat:
        label: 'Heating'
        desc: 'CO2 emissions due to heating the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: -> calcEnergyC02.call(@, 'energy_demand.src_heat', 'energy_demand.en_heat')
      co2_cool:
        label: 'Cooling'
        desc: 'CO2 emissions due to cooling the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$energy_demand.en_cool * KWH_TO_MJ($operating_carbon.elec)'
      co2_light:
        label: 'Lighting'
        desc: 'CO2-e emissions due to lighting the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$energy_demand.en_light * $operating_carbon.elec'
      co2_hwat:
        label: 'Hot Water'
        desc: 'CO2-e emissions due to hot water heating in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: ->
          co2 = calcEnergyC02.call(@, 'energy_demand.src_hwat', 'energy_demand.en_hwat')
          if co2? then co2 * 1000 else null
      co2_cook:
        label: 'Cooktop and Oven'
        desc: 'CO2-e emissions due to cooking in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: -> calcEnergyC02.call(@, 'energy_demand.src_cook', 'energy_demand.en_cook')
      co2_app:
        label: 'Appliances'
        desc: 'CO2-e emissions due to powering appliances in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$energy_demand.en_app * KWH_TO_MJ($operating_carbon.elec)'
      co2_trans:
        label: 'Transport'
        desc: 'CO2-e emissions due to transport.'
        type: Number
        decimal: true
        units: Units.kgco2
      # TODO(aramk) Add once we have pathways.
        calc: '0'
      co2_op_tot:
        label: 'Total Operating'
        desc: 'Total operating CO2 from all energy uses.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: ->
          if classHasIntensity(Entities.getTypologyClass(@model._id))
            @calc('$operating_carbon.co2_op_e + $operating_carbon.co2_op_g')
          else
            @calc('$operating_carbon.co2_heat + $operating_carbon.co2_cool + $operating_carbon.co2_light + $operating_carbon.co2_hwat + $operating_carbon.co2_cook + $operating_carbon.co2_app - ($energy_demand.en_pv * $operating_carbon.elec)')
      co2_op_e:
        desc: 'Operating CO2 from electricity use.'
        label: 'CO2 - Electricity'
        type: Number
        units: Units.kgco2
        calc: '(MJ_TO_KWH($energy_demand.en_use_e) - $energy_demand.en_pv) * $operating_carbon.elec'
      co2_op_g:
        desc: 'Operating CO2 from gas use.'
        label: 'CO2 - Gas'
        type: Number
        units: Units.kgco2
        calc: 'MJ_TO_KWH($energy_demand.en_use_g) * $operating_carbon.elec'
  water_demand:
    label: 'Water Demand'
    items:
      i_wu_pot:
        label: 'Internal Potable Water Use'
        desc: 'Internal potable water use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        classes:
          RESIDENTIAL: {}
      i_wu_bore:
        label: 'Internal Bore Water Use'
        desc: 'Internal bore water use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        classes:
          RESIDENTIAL: {}
      i_wu_rain:
        label: 'Internal Rain Water Use'
        desc: 'Internal rain water use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        classes:
          RESIDENTIAL: {}
      i_wu_treat:
        label: 'Internal Treated Water Use'
        desc: 'Internal treated water use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        classes:
          RESIDENTIAL: {}
      i_wu_grey:
        label: 'Internal Grey Water Use'
        desc: 'Internal grey water use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        classes:
          RESIDENTIAL: {}
      i_wu_intensity:
        desc: 'Internal potable water use intensity of the typology.'
        label: 'Internal Water Use Intensity'
        type: Number
        decimal: true
        units: Units.kLm2year
        classes:
          COMMERCIAL:
            subclasses:
              'Retail': {defaultValue: 1.7}
              'Office': {defaultValue: 1.01}
              'Hotel': {defaultValue: 328}
              'Supermarket': {defaultValue: 3.5}
              'Restaurant': {defaultValue: 11.3}
          INSTITUTIONAL:
            subclasses:
              'School': {defaultValue: 3.25}
              'Tertiary': {defaultValue: 3.25}
              'Hospital': {defaultValue: 1.5}
              'Public': {defaultValue: 3.3}
      i_wu_total:
        label: 'Internal Total Water Use'
        desc: 'Total internal water use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: ->
          if classHasIntensity(Entities.getTypologyClass(@model._id))
            @calc('$water_demand.i_wu_intensity * $space.gfa')
          else
            @calc('$water_demand.i_wu_pot + $water_demand.i_wu_bore + $water_demand.i_wu_rain + $water_demand.i_wu_treat + $water_demand.i_wu_grey')
      e_wd_lawn:
        label: 'External Water Demand - Lawn'
        desc: 'External water demand of lawn.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: '$space.ext_land_l * $external_water.demand_lawn'
      e_wd_ap:
        label: 'External Water Demand - Annual Plants'
        desc: 'External water demand of annual plants.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: '$space.ext_land_a * $external_water.demand_ap'
      e_wd_hp:
        label: 'External Water Demand - Hardy Plants'
        desc: 'External water demand of hardy plants.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: '$space.ext_land_h * $external_water.demand_hp'
      e_wd_total:
        label: 'External Water Demand - Total'
        desc: 'Total external water demand of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: '$water_demand.e_wd_lawn + $water_demand.e_wd_ap + $water_demand.e_wd_hp'
      e_prpn_pot:
        label: 'External Proportion Potable Water'
        type: Number
        decimal: true
        desc: 'Proportion of water as potable water.'
        classes: extendClassesWithDefault(extendLandClasses(), 1)
      e_prpn_bore:
        label: 'External Proportion Bore Water'
        type: Number
        decimal: true
        desc: 'Proportion of irrigation as bore water.'
        classes: extendClassesWithDefault(extendLandClasses(), 0)
      e_prpn_storm:
        label: 'External Proportion Stormwater Water'
        type: Number
        decimal: true
        desc: 'Proportion of irrigation as stormwater.'
        classes: extendClassesWithDefault(extendLandClasses(), 0)
      e_prpn_treat:
        label: 'External Proportion Treated Water'
        type: Number
        decimal: true
        desc: 'Proportion of irrigation as treated/recycled.'
        classes: extendClassesWithDefault(extendLandClasses(), 0)
      e_prpn_grey:
        label: 'External Proportion Grey Water'
        type: Number
        decimal: true
        desc: 'Proportion of irrigation as grey.'
        classes: extendClassesWithDefault(extendLandClasses(), 0)
      e_wu_pot:
        label: 'Potable Water Use'
        type: Number
        desc: 'Potable water use for irrigation.'
        units: Units.kLyear
        calc: '$water_demand.e_wd_total * $water_demand.e_prpn_pot'
      e_wu_bore:
        label: 'Bore Water Use'
        type: Number
        desc: 'Bore water use for irrigation.'
        units: Units.kLyear
        calc: '$water_demand.e_wd_total * $water_demand.e_prpn_bore'
      e_wu_storm:
        label: 'Stormwater Water Use'
        type: Number
        desc: 'Stormwater use for irrigation.'
        units: Units.kLyear
        calc: '$water_demand.e_wd_total * $water_demand.e_prpn_storm'
      e_wu_treat:
        label: 'Treated Water Use'
        type: Number
        desc: 'Treated water use for irrigation.'
        units: Units.kLyear
        calc: '$water_demand.e_wd_total * $water_demand.e_prpn_treat'
      e_wu_grey:
        label: 'Grey Water Use'
        type: Number
        desc: 'Grey water use for irrigation.'
        units: Units.kLyear
        calc: '$water_demand.e_wd_total * $water_demand.e_prpn_grey'
      # TODO(aramk) Migrate this for the residential schema to use those above.
      wu_pot_tot:
        label: 'Total Potable Water Use'
        desc: 'Total potable water use for internal and external purposes.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: ->
          if classHasIntensity(Entities.getTypologyClass(@model._id))
            i_wu_pot = @param('water_demand.i_wu_total')
          else
            i_wu_pot = @param('water_demand.i_wu_pot')
          i_wu_pot + @param('water_demand.e_wu_pot')
      wd_total:
        label: 'Total Water Demand'
        desc: 'Total water use for internal and external purposes.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: '$water_demand.i_wu_total + $water_demand.e_wd_total'
  stormwater:
    label: 'Stormwater'
    items:
      runoff:
        label: 'Stormwater Runoff'
        desc: 'Stormwater run-off during an extreme storm event.'
        type: Number
        units: Units.Lsec
        calc: '($space.fpa * $stormwater.runoff_roof + $space.ext_land_i * $stormwater.runoff_impervious + ($space.ext_land_l + $space.ext_land_a + $space.ext_land_h) * $stormwater.runoff_pervious) * $stormwater.rainfall_intensity / 3600'
      runoff_rd:
        label: 'Stormwater Runoff'
        desc: 'Stormwater run-off during an extreme storm event.'
        type: Number
        units: Units.Lsec
        calc: '(($composition.rd_area + $composition.prk_area + $composition.fp_area + $composition.bp_area) * $stormwater.runoff_impervious + $composition.ve_area * $stormwater.runoff_pervious) * $stormwater.rainfall_intensity / 3600'
  financial:
    label: 'Financial'
    items:
      build_type:
        label: 'Build Type'
        type: String
        desc: 'The build type of the typology.'
        classes:
          RESIDENTIAL:
            defaultValue: 'Custom'
            allowedValues: Object.keys(ResidentialBuildTypes)
            getCostParamId: (args) ->
              'financial.residential.' + ResidentialBuildTypes[args.value]?[args.subclass]
          COMMERCIAL: createBuildTypeClassOptions(CommercialBuildTypes, 'commercial')
          INSTITUTIONAL: createBuildTypeClassOptions(InstitutionalBuildTypes, 'institutional')
      cost_land:
        label: 'Cost - Land Parcel'
        type: Number
        decimal: true
        desc: 'Value of the parcel of land.'
        units: Units.$
        calc: -> @param('space.lotsize') * calcLandPrice.call(@)
      cost_lawn:
        label: 'Cost - Lawn'
        desc: 'Cost of installing lawn.'
        type: Number
        units: Units.$
        calc: '$space.ext_land_l * $financial.landscaping.price_lawn'
      cost_annu:
        label: 'Cost - Annual Plants'
        desc: 'Cost of installing annual plants.'
        type: Number
        units: Units.$
        calc: '$space.ext_land_a * $financial.landscaping.price_annu'
      cost_hardy:
        label: 'Cost - Hardy Plants'
        desc: 'Cost of installing hardy plants.'
        type: Number
        units: Units.$
        calc: '$space.ext_land_h * $financial.landscaping.price_hardy'
      cost_imper:
        label: 'Cost - Impermeable'
        desc: 'Cost of laying impermeable surfaces.'
        type: Number
        units: Units.$
        calc: '$space.ext_land_i * $financial.landscaping.price_imper'
      cost_xland:
        label: 'Cost - Total Landscaping'
        desc: 'Total cost of landscaping external areas.'
        type: Number
        units: Units.$
        calc: '$financial.cost_lawn + $financial.cost_annu + $financial.cost_hardy + $financial.cost_imper'
      cost_con:
        label: 'Cost - Building Construction'
        desc: 'Cost of constructing the typology estimated using the Rawlinson’s Construction Handbook.'
        type: Number
        units: Units.$
        classes: BuildingClasses
      cost_prop:
        label: 'Cost - Property'
        desc: 'Total cost of the developing the property.'
        type: Number
        units: Units.$
        calc: '$financial.cost_land + $financial.cost_xland + $financial.cost_con'
      cost_op_e:
        label: 'Cost - Electricity Usage'
        desc: 'Operating costs due to electricity usage.'
        type: Number
        decimal: true
        units: Units.$
        calc: ->
          if classHasIntensity(Entities.getTypologyClass(@model._id))
            calcEnergyWithIntensityCost.call(@, 'elec', 'e')
          else
            calcEnergyCost.call(@, 'Electricity', 'elec')
      cost_op_g:
        label: 'Cost - Gas Usage'
        desc: 'Operating costs due to gas usage.'
        type: Number
        decimal: true
        units: Units.$
        calc: ->
          if classHasIntensity(Entities.getTypologyClass(@model._id))
            calcEnergyWithIntensityCost.call(@, 'gas', 'g')
          else
            calcEnergyCost.call(@, 'Gas', 'gas')
      cost_op_w:
        label: 'Cost - Water Usage'
        desc: 'Operating costs due to water usage.'
        type: Number
        decimal: true
        units: Units.$
        calc: '$utilities.price_supply_water + $water_demand.wu_pot_tot * $utilities.price_usage_water'
      cost_op_t:
        label: 'Cost - Total Operating'
        desc: 'Total operating cost of the typology including electricity and gas usage.'
        type: Number
        decimal: true
        units: Units.$
        calc: '$financial.cost_op_e + $financial.cost_op_g + $financial.cost_op_w'
      pathways:
        items:
          cost_land:
            desc: 'Value of the area of land.'
            label: 'Cost - Land'
            type: Number
            units: Units.$
            calc: -> @param('space.area') * calcLandPrice.call(@)
          cost_rd:
            desc: 'Road surface cost.'
            label: 'Cost - Road'
            type: Number
            units: Units.$
            calc: ->
              area = @param('composition.rd_area')
              mat = @param('composition.rd_mat')
              price = @param('financial.pathways.roads.price_' + RoadMaterialTypes[mat])
              area * price
          cost_prk:
            desc: 'Parking surface cost.'
            label: 'Cost - Parking'
            type: Number
            units: Units.$
            calc: ->
              area = @param('composition.prk_area')
              mat = @param('composition.prk_mat')
              price = @param('financial.pathways.roads.price_' + RoadMaterialTypes[mat])
              area * price
          cost_fp:
            desc: 'Footpath surface cost.'
            label: 'Cost - Footpath'
            type: Number
            units: Units.$
            calc: ->
              area = @param('composition.fp_area')
              mat = @param('composition.fp_mat')
              price = @param('financial.pathways.footpaths.price_' + FootpathMaterialTypes[mat])
              area * price
          cost_bp:
            desc: 'Bicycle path surface cost.'
            label: 'Cost - Bicycle Path'
            type: Number
            units: Units.$
            calc: ->
              area = @param('composition.bp_area')
              mat = @param('composition.bp_mat')
              price = @param('financial.pathways.bicycle_paths.price_' + BicyclePathMaterialTypes[mat])
              area * price
          cost_ve:
            desc: 'Verge surface cost.'
            label: 'Cost - Verge'
            type: Number
            units: Units.$
            calc: '$composition.ve_area * $financial.pathways.all.price_verge'
          cost_con:
            desc: 'Total cost of constructing the pathway.'
            label: 'Cost - Construction'
            type: Number
            units: Units.$
            calc: ->
              sum = 0
              _.each ['rd', 'prk', 'fp',  'bp', 've'], (paramId) =>
                sum += @param('financial.pathways.cost_' + paramId)
              sum
          cost_total:
            desc: 'Total cost of the drawn pathway including land and construction.'
            label: 'Cost - Total'
            type: Number
            units: Units.$
            calc: '$financial.pathways.cost_con + $financial.pathways.cost_land'
  orientation:
    label: 'Orientation'
    items:
      azimuth:
        label: 'Azimuth'
        desc: 'Orientation of the typology with north as 0 degrees.'
        type: Number
        decimal: true
        units: 'Degrees'
        classes: BuildingClasses
      eq_azmth_h:
        label: 'Azimuth Heating Energy Array'
        desc: 'Equation to predict heating energy use as a function of degrees azimuth.'
        type: String
        classes: BuildingClasses
      eq_azmth_c:
        label: 'Azimuth Cooling Energy Array'
        desc: 'Equation to predict cooling energy use as a function of degrees azimuth.'
        type: String
        classes: BuildingClasses
  parking:
    label: 'Parking'
    items:
      parking_ga:
        label: 'Parking Spaces - Garage'
        desc: 'Number of garage parking spaces.'
        type: Number
        units: Units.spaces
        classes:
          RESIDENTIAL: {}
      parking_ug:
        label: 'Parking Spaces - Underground'
        desc: 'Number of underground parking spaces.'
        type: Number
        units: Units.spaces
        classes: BuildingClasses
      parking_sl:
        label: 'Parking Spaces - Street Level'
        desc: 'Number of street level parking spaces.'
        type: Number
        units: Units.spaces
        calc: '$space.ext_land_i * $parking.parking_land / $parking.prk_area_veh'
      parking_t:
        label: 'Parking Spaces - Total'
        desc: 'Total number of parking spaces.'
        type: Number
        units: Units.spaces
        calc: '$parking.parking_ga + $parking.parking_sl + $parking.parking_ug'
      parking_rd:
        label: 'Parking Spaces per Metre'
        desc: 'Number of parking spaces per metre length of pathway.'
        type: Number
        units: Units.spacesm
        classes:
          PATHWAY: {defaultValue: 0.165}
      parking_rd_total:
        label: 'Total Parking Spaces'
        desc: 'Total number of parking spaces of the drawn pathway.'
        type: Number
        units: Units.spaces
        calc: '$space.length * $parking.parking_rd'
      parking_land:
        label: 'Parking Land Ratio'
        desc: 'Proportion of impervious land available for parking.'
        type: Number
        decimal: true
        classes:
          RESIDENTIAL: {defaultValue: 0.2}
          COMMERCIAL: {defaultValue: 0.9}
          MIXED_USE: {defaultValue: 0.8}
          INSTITUTIONAL: {defaultValue: 0.9}
  composition:
    label: 'Composition'
    items:
      rd_lanes:
        desc: 'Number of road lanes for vehicular movement.'
        label: 'No. Road Lanes'
        type: Number
        units: Units.lanes
        classes:
          PATHWAY:
            defaultValue: 0
      rd_width:
        desc: 'Width of the road for vehicular movement.'
        label: 'Road Width'
        type: Number
        decimal: true
        units: Units.m
        classes:
          PATHWAY:
            defaultValue: 3.5
      rd_area:
        desc: 'Area of the drawn road for vehicular movement.'
        label: 'Road Area'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$composition.rd_lanes * $composition.rd_width * $space.length'
      rd_mat:
        desc: 'Material used in the construction of the road surface.'
        label: 'Road Profile'
        type: String
        allowedValues: Object.keys(RoadMaterialTypes)
        classes:
          PATHWAY:
            defaultValue: 'Full Depth Asphalt'
      prk_lanes:
        desc: 'Number of lanes for vehicle parking.'
        label: 'No. Parking Lanes'
        type: Number
        units: Units.lanes
        classes:
          PATHWAY:
            defaultValue: 0
      prk_width:
        desc: 'Width of the drawn pathway for vehicle parking.'
        label: 'Parking Width'
        type: Number
        decimal: true
        units: Units.m
        classes:
          PATHWAY:
            defaultValue: 3
      prk_area:
        desc: 'Area of a drawn pathway for vehicle parking.'
        label: 'Parking Area'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$composition.prk_lanes * $composition.prk_width * $space.length'
      prk_mat:
        desc: 'Material used in the construction of the parking surface.'
        label: 'Parking Profile'
        type: String
        allowedValues: Object.keys(RoadMaterialTypes)
        classes:
          PATHWAY:
            defaultValue: 'Full Depth Asphalt'
      fp_lanes:
        desc: 'Number of footpath lanes for pedestrian movement.'
        label: 'No. Footpath Lanes'
        type: Number
        units: Units.lanes
        classes:
          PATHWAY:
            defaultValue: 0
      fp_width:
        desc: 'Width of a footpath for pedestrian movement.'
        label: 'Footpath Width'
        type: Number
        decimal: true
        units: Units.m
        classes:
          PATHWAY:
            defaultValue: 2
      fp_area:
        desc: 'Area of the drawn pedestrian footpath.'
        label: 'Footpath Area'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$composition.fp_lanes * $composition.fp_width * $space.length'
      fp_mat:
        desc: 'Material used in the construction of the footpath surface.'
        label: 'Footpath Profile'
        type: String
        allowedValues: Object.keys(FootpathMaterialTypes)
        classes:
          PATHWAY:
            defaultValue: 'Concrete'
      bp_lanes:
        desc: 'Number of bicycle path lanes for cyclist movement.'
        label: 'No. Bicycle Path Lanes'
        type: Number
        units: Units.lanes
        classes:
          PATHWAY:
            defaultValue: 0
      bp_width:
        desc: 'Width of a bicycle path lane for cyclist movement.'
        label: 'Bicycle Path Width'
        type: Number
        decimal: true
        units: Units.m
        classes:
          PATHWAY:
            defaultValue: 2
      bp_area:
        desc: 'Area of the drawn bicycle path.'
        label: 'Bicycle Path Area'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$composition.bp_lanes * $composition.bp_width * $space.length'
      bp_mat:
        desc: 'Material used in the construction of the bicycle path surface.'
        label: 'Bicycle Path Profile'
        type: String
        allowedValues: Object.keys(BicyclePathMaterialTypes)
        classes:
          PATHWAY:
            defaultValue: 'Asphalt'
      ve_lanes:
        desc: 'Number of verge strips as a buffer for the pathway.'
        label: 'No. Verge Strips'
        type: Number
        units: 'Lanes'
        classes:
          PATHWAY:
            defaultValue: 2
      ve_width:
        desc: 'Width of verge as a buffer for the pathway.'
        label: 'Verge Width'
        type: Number
        decimal: true
        units: 'm'
        classes:
          PATHWAY:
            defaultValue: 2
      ve_area:
        desc: 'Area of the drawn verge.'
        label: 'Verge Area'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$composition.ve_lanes * $composition.ve_width * $space.length'
  transport:
    label: 'Transport'
    items:
      # VKT MODEL
      vkt_household_day:
        label: 'VKT Estimate (per Household)'
        desc: 'Vehicle kilometres travelled per household per day.'
        type: Number
        decimal: true
        units: Units.kmday
        calc: ->
          params = TransportModelParameters
          value = calcTransportLinearRegression.call(@, params)
          Math.pow(value, 2)
      vkt_person_day:
        label: 'VKT Estimate (per Resident)'
        desc: 'Vehicle kilometres travelled per resident per day.'
        type: Number
        decimal: true
        units: Units.kmday
        calc: '$transport.vkt_household_day / $transport.hhsize'
      vkt_household_year:
        label: 'VKT Estimate (per Household)'
        desc: 'Vehicle kilometres travelled per household per year.'
        type: Number
        decimal: true
        units: Units.kmyear
        calc: '$transport.vkt_household_day * 365'
      vkt_person_year:
        label: 'VKT Estimate (per Resident)'
        desc: 'Vehicle kilometres travelled per resident per year.'
        type: Number
        decimal: true
        units: Units.kmyear
        calc: '$transport.vkt_person_day * 365'
      ghg_household_day:
        label: 'GHG Estimate (per Household)'
        desc: 'Greenhouse gas emissions per household per day.'
        type: Number
        decimal: true
        units: Units.kgco2day
        calc: '$transport.vkt_household_day * $operating_carbon.vkt'
      ghg_person_day:
        label: 'GHG Estimate (per Resident)'
        desc: 'Greenhouse gas emissions per resident per day.'
        type: Number
        decimal: true
        units: Units.kgco2day
        calc: '$transport.vkt_person_day * $operating_carbon.vkt'
      ghg_household_year:
        label: 'GHG Estimate (per Household)'
        desc: 'Greenhouse gas emissions per household per year.'
        type: Number
        decimal: true
        units: Units.kgco2day
        calc: '$transport.ghg_household_day * 365'
      ghg_person_year:
        label: 'GHG Estimate (per Resident)'
        desc: 'Greenhouse gas emissions per resident per year.'
        type: Number
        decimal: true
        units: Units.kgco2day
        calc: '$transport.ghg_person_day * 365'
      # MODE SHARE MODEL
      exp_vehpass:
        desc: 'Vehicle as passenger mode share expotential'
        type: Number
        decimal: true
        calc: ->
          params = TransportModeShareModel.VEHPASS
          value = calcTransportLinearRegression.call(@, params)
          Math.exp(value)
      exp_transit:
        desc: 'Transit mode share expotential'
        type: Number
        decimal: true
        calc: ->
          params = TransportModeShareModel.TRANSIT
          value = calcTransportLinearRegression.call(@, params)
          Math.exp(value)
      exp_active:
        desc: 'Active mode share expotential'
        type: Number
        decimal: true
        calc: ->
          params = TransportModeShareModel.ACTIVE
          value = calcTransportLinearRegression.call(@, params)
          Math.exp(value)
      exp_total:
        desc: 'Total of mode share expotentials'
        type: Number
        decimal: true
        calc: '$transport.exp_vehpass + $transport.exp_transit + $transport.exp_active'
      mode_share_car_driver:
        label: 'Mode Share - Car as Driver'
        type: Number
        decimal: true
        calc: '1 / (1 + $transport.exp_total)'
      mode_share_car_passenger:
        label: 'Mode Share - Car as Passenger'
        type: Number
        decimal: true
        calc: '$transport.exp_vehpass / (1 + $transport.exp_total)'
      mode_share_transit:
        label: 'Mode Share - Transit'
        type: Number
        decimal: true
        calc: '$transport.exp_transit / (1 + $transport.exp_total)'
      mode_share_active:
        label: 'Mode Share - Active'
        type: Number
        decimal: true
        calc: '$transport.exp_active / (1 + $transport.exp_total)'
      total_trips:
        label: 'Total Trips'
        type: Number
        units: Units.tripsday
        calc: '$transport.trips'
      trips_car_driver:
        label: 'Car as Driver Trips'
        type: Number
        units: Units.tripsday
        calc: '$transport.total_trips * $transport.mode_share_car_driver'
      trips_car_passenger:
        label: 'Car as Passenger Trips'
        type: Number
        units: Units.tripsday
        calc: '$transport.total_trips * $transport.mode_share_car_passenger'
      trips_car_transit:
        label: 'Transit Trips'
        type: Number
        units: Units.tripsday
        calc: '$transport.total_trips * $transport.mode_share_transit'
      trips_car_active:
        label: 'Active Trips'
        type: Number
        units: Units.tripsday
        calc: '$transport.total_trips * $transport.mode_share_active'
      total_trips_year:
        label: 'Total Trips'
        type: Number
        units: Units.tripsyear
        calc: '$transport.total_trips * 365'
      trips_car_driver_year:
        label: 'Car as Driver Trips'
        type: Number
        units: Units.tripsyear
        calc: '$transport.trips_car_driver * 365'
      trips_car_passenger_year:
        label: 'Car as Passenger Trips'
        type: Number
        units: Units.tripsyear
        calc: '$transport.trips_car_passenger * 365'
      trips_car_transit_year:
        label: 'Transit Trips'
        type: Number
        units: Units.tripsyear
        calc: '$transport.trips_car_transit * 365'
      trips_car_active_year:
        label: 'Active Trips'
        type: Number
        units: Units.tripsyear
        calc: '$transport.trips_car_active * 365'

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
    defaultValue: {}
  project: projectSchema

@Typologies = new Meteor.Collection 'typologies'
Typologies.attachSchema(TypologySchema)
Typologies.classes = TypologyClasses
Typologies.units = Units
Typologies.allow(Collections.allowAll())

Typologies.getClassByName = _.memoize (name) ->
  matchedId = null
  sanitize = (str) -> ('' + str).toLowerCase().trim()
  name = sanitize(name)
  for id, cls of TypologyClasses
    if sanitize(cls.name) == name
      matchedId = id
  matchedId

# Typologies.getClassAbbreviation = _.memoize (typologyClass) ->
#   for id, cls of TypologyClasses
#     if cls.abbr == typologyClass
#       matchedId = id

Typologies.getClassItems = ->
  _.map Typologies.classes, (cls, id) -> Setter.merge(Setter.clone(cls), {_id: id})

Typologies.getSubclassItems = (typologyClass) ->
  field = SchemaUtils.getField('parameters.general.subclass', Typologies)
  options = field?.classes[typologyClass]
  allowedValues = options?.allowedValues ? []
  _.map allowedValues, (value) -> {_id: value, name: value}

Typologies.getBuildTypeItems = (typologyClass, subclass) ->
  field = SchemaUtils.getField('parameters.financial.build_type', Typologies)
  options = field?.classes[typologyClass]
  allowedValues = options?.allowedValues ? []
  if Types.isFunction(allowedValues)
    allowedValues = allowedValues(typologyClass: typologyClass, subclass: subclass)
  _.map allowedValues, (value) -> {_id: value, name: value}

# TODO(aramk) Move to objects util.
Typologies.getModifierProperty = (obj, property) ->
  target = obj
  segments = property.split('.')
  unless segments.length > 0
    return undefined
  for key in segments
    target = target[key]
    unless target?
      break
  target

# TODO(aramk) Move to objects util.
Typologies.setModifierProperty = (obj, property, value) ->
  segments = property.split('.')
  unless segments.length > 0
    return false
  lastSegment = segments.pop()
  for key in segments
    target = obj[key] ?= {}
  target[lastSegment] = value
  true

Typologies.unflattenParameters = (doc, hasParametersPrefix) ->
  Objects.unflattenProperties doc, (key) ->
    if !hasParametersPrefix or /^parameters\./.test(key)
      key.split('.')
    else
      null
  doc

Typologies.getDefaultParameterValues = ->
  if Types.isString(arguments[0])
    [typologyClass, subclass] = arguments
  else
    typology = arguments[0]
    typologyClass = SchemaUtils.getParameterValue(typology, 'general.class')
    subclass = SchemaUtils.getParameterValue(typology, 'general.subclass')
  Typologies._getDefaultParameterValues(typologyClass: typologyClass, subclass: subclass)

Typologies._getDefaultParameterValues = _.memoize(
  (args) ->
    typologyClass = args.typologyClass
    subclass = args.subclass
    values = {}
    SchemaUtils.forEachFieldSchema ParametersSchema, (fieldSchema, paramId) ->
      # NOTE: This does not look for official defaultValue in the schema, only in the class options.
      classes = fieldSchema.classes
      classOptions = classes?[typologyClass]
      classDefaultValue = classOptions?.defaultValue
      subclassDefaultValue = classOptions?.subclasses?[subclass]?.defaultValue
      allClassDefaultValue = classes?.ALL?.defaultValue
      defaultValue = subclassDefaultValue ? classDefaultValue ? allClassDefaultValue
      if defaultValue?
        values[paramId] = defaultValue
    Typologies.unflattenParameters(values, false)
  (args) -> JSON.stringify(args)
)

# Get the parameters which have default values for other classes and should be excluded from models
# of the class.
Typologies.getExcludedDefaultParameters = _.memoize (typologyClass) ->
  excluded = {}
  SchemaUtils.forEachFieldSchema ParametersSchema, (fieldSchema, paramId) ->
    classes = fieldSchema.classes
    if classes and !classes[typologyClass]
      excluded[paramId] = true
  Typologies.unflattenParameters(excluded, false)

mergeDefaultParameters = (model, defaults) ->
  model.parameters ?= {}
  Setter.defaults(model.parameters, defaults)
  model

Typologies.mergeDefaults = (model) ->
  defaults = Typologies.getDefaultParameterValues(model)
  mergeDefaultParameters(model, defaults)

# Filters parameters which don't belong to the class assigned to the given model. This does not
# affect reports since only fields matching the class should be included, but is a fail-safe for
# when calculated expressions may conditionally reference fields outside their class, since it's
# possible to change the class of a typology and this keeps the values for fields only applicable
# to the old typology.
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

Typologies.findByProject = (projectId) -> SchemaUtils.findByProject(Typologies, projectId)

Typologies.getClassMap = (projectId) ->
  typologies = Typologies.findByProject(projectId).fetch()
  typologyMap = {}
  _.each typologies, (typology) ->
    typologyClass = SchemaUtils.getParameterValue(typology, 'general.class')
    map = typologyMap[typologyClass] ?= []
    map.push(typology)
  typologyMap

Typologies.findByClass = (typologyClass, projectId) -> Typologies.find(
  'parameters.general.class': typologyClass
  project: projectId || Projects.getCurrentId()
)

Typologies.getTypologyClass = (id) ->
  typology = Typologies.findOne(id)
  SchemaUtils.getParameterValue(typology, 'general.class')

# @returns the fields that are required for the given typology class. Excludes fields which are
# required by all classes.
Typologies.getRequiredFieldsForClass = _.memoize (typologyClass) ->
  fields = []
  SchemaUtils.forEachFieldSchema Typologies.simpleSchema(), (fieldSchema, fieldId) ->
    optional = fieldSchema.classes?[typologyClass]?.optional
    fields.push(fieldId) if optional == false
  fields

Typologies.validate = (typology) ->
  typologyClass = SchemaUtils.getParameterValue(typology, 'parameters.general.class')
  _.each Typologies.getRequiredFieldsForClass(typologyClass), (fieldId) ->
    throw new Error('Field ' + fieldId + ' is required for Typologies with class ' +
      typologyClass) unless SchemaUtils.getParameterValue(typology, fieldId)?

Collections.addValidation(Typologies, Typologies.validate)

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
    optional: false
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
    collectionType: 'Entities'
# TODO(aramk) Disabled this complex validation for now to avoid it causing issues when
# creating lots manually.
#    custom: ->
#      classParamId = 'parameters.general.class'
#      developFieldId = 'parameters.general.develop'
#      typologyClassField = @siblingField(classParamId)
#      developField = @siblingField(developFieldId)
#      unless (typologyClassField.isSet && this.isSet && developField.isSet) || @operator == '$unset'
#        # TODO(aramk) This isn't guaranteed to work if typology field is not set at same time as
#        # entity. Look up the actual value using an ID.
#        return 'Class, entity and develop fields must be set together for validation to work, ' +
#            'unless entity is being removed.'
#      if typologyClassField.operator == '$unset' && @operator != '$unset'
#        return 'Class must be present if entity is present.'
#      entityId = @value
#      unless entityId
#        return
#      entityTypology = Typologies.findOne(Entities.findOne(entityId).typology)
#      entityClass = SchemaUtils.getParameterValue(entityTypology, classParamId)
#      typologyClass = typologyClassField.value
#      if typologyClassField.operator != '$unset' && @operator != '$unset' && typologyClass != entityClass
#        return 'Entity must have the same class as the Lot. Entity has ' + entityClass +
#            ', Lot has ' + typologyClass
#      if developField.operator != '$unset' && @operator != '$unset' && !developField.value
#        return 'Lot which is not for development cannot have Entity assigned.'
  parameters:
    label: 'Parameters'
    type: LotParametersSchema
    defaultValue: {}
  project: projectSchema

@Lots = new Meteor.Collection 'lots'
Lots.attachSchema(LotSchema)
Lots.allow(Collections.allowAll())

Lots.findByProject = (projectId) -> SchemaUtils.findByProject(Lots, projectId)
Lots.findByEntity = (entityId) -> Lots.findOne({entity: entityId})
Lots.findByTypology = (typologyId) ->
  _.map Entities.find(typology: typologyId).fetch(), (entity) -> Lots.findByEntity(entity._id)
Lots.findForDevelopment = (projectId) ->
  _.filter Lots.findByProject(projectId).fetch(), (lot) ->
    SchemaUtils.getParameterValue(lot, 'general.develop')
Lots.findAvailable = (projectId) ->
  _.filter Lots.findForDevelopment(projectId), (lot) -> !lot.entity

Lots.createEntity = (lotId, typologyId, allowReplace) ->
  allowReplace ?= false
  df = Q.defer()
  lot = Lots.findOne(lotId)
  if lot.entity && !allowReplace
    throw new Error('Cannot replace entity on existing Lot with ID ' + lotId)
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
  lotClass = SchemaUtils.getParameterValue(lot, classParamId)
  isForDevelopment = SchemaUtils.getParameterValue(lot, developParamId)
  # If no class is provided, use the class of the entity's typology.
  unless lotClass
    lotClass = SchemaUtils.getParameterValue(typology, classParamId)
  Lots.validateTypology(lot, typologyId).then (result) ->
    if result
      console.error('Cannot create Entity on Lot:', result)
      df.reject(result)
      return
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

Lots.createOrReplaceEntity = (lotId, newTypologyId) ->
  entityDf = Q.defer()
  lot = Lots.findOne(lotId)
  oldEntityId = lot.entity
  oldTypologyId = oldEntityId && Entities.findOne(oldEntityId).typology
  if newTypologyId && oldTypologyId != newTypologyId
    # Create a new entity for the lot, removing the old one.
    Lots.createEntity(lotId, newTypologyId, true).then(
      (newEntityId) -> entityDf.resolve(newEntityId)
      (err) -> entityDf.reject(err)
    )
  else
    entityDf.resolve(oldEntityId)
  entityDf.promise

Lots.validate = (lot) ->
  entityId = lot.entity
  # Avoid an exception preventing a collection method from being called - especially if it's to
  # delete invalid collections.
  try
    typology = entityId && Typologies.findOne(Entities.findOne(entityId).typology)
    typologyId = typology && typology._id
    validateTypology = typologyId && Lots.validateTypology(lot, typologyId)
    if validateTypology
      return validateTypology
  catch e
    console.error('Lot could not be validated', lot, e, e.stack)

Lots.validateTypology = (lot, typologyId) ->
  df = Q.defer()
  # Validates whether adding the given typology is valid on the given lot.
  typology = Typologies.findOne(typologyId)
  unless typology
    df.reject('Cannot find typology with ID ' + typologyId)
    return df.promise
  classParamId = 'parameters.general.class'
  developParamId = 'parameters.general.develop'
  lotClass = SchemaUtils.getParameterValue(lot, classParamId)
  typologyClass = SchemaUtils.getParameterValue(typology, classParamId)
  isForDevelopment = SchemaUtils.getParameterValue(lot, developParamId)
  if typologyId && !isForDevelopment
    df.resolve('Lot is not for development - cannot assign typology.')
  else if !lotClass
    df.resolve('Lot does not have a Typology class assigned.')
  else if typologyClass != lotClass
    df.resolve('Lot does not have same Typology class as the Typology being assigned.')
  else
    # Ensure the geometry of the typology will fit in the lot.
    areaDfs = [GeometryUtils.getModelArea(typology), GeometryUtils.getModelArea(lot)]
    Q.all(areaDfs).then (results) ->
      lotArea = results.pop()?.area
      typologyArea = results.pop()?.area
      if lotArea? && typologyArea? && lotArea <= typologyArea
        df.resolve('Typology must have area less than or equal to the Lot.')
      else
        df.resolve()
  df.promise

Collections.addValidation(Lots, Lots.validate)

# TODO(aramk) Disabled this for now until validation is cleaner to define. Logic is still in
# typologyForm.
# Typologies.validate = (typology) ->
#   # When changing the class, if there is an existing entity, prevent the change if it doesn't match
#   # the same class.
#   classParamId = 'parameters.general.class'
#   newClass = modifier.$set[classParamId]
#   if newClass
#     oldTypology = Typologies.findOne(docId)
#     oldClass = SchemaUtils.getParameterValue(oldTypology, classParamId)
#     if newClass != oldClass
#       lots = Lots.findByTypology(docId)
#       lotCount = lots.length
#       if lotCount > 0
#         lotNames = (_.map lots, (lot) -> lot.name).join(', ')
#         alert('These Lots are using this Typology: ' + lotNames + '. Remove this Typology' +
#           ' from the Lot first before changing its class.')
#         @result(false)

# Typologies.before.insert (userId, doc) ->
#   inValid = Typologies.validate(doc)
#   if inValid
#     throw new Error(inValid)

# Typologies.before.update (userId, doc, fieldNames, modifier) ->
#   doc = simulateModifierUpdate(doc, modifier)
#   isInvalid = Typologies.validate(doc)
#   if inValid
#     throw new Error(inValid)

####################################################################################################
# ENTITY SCHEMA DEFINITION
####################################################################################################

entityCategories = Setter.clone(typologyCategories)
# Entities have the same parameters as typologies, so any required fields are expected to exist on
# the typology and are no longer required for the entities, so we remove them here.
removeRequiredPropertyFromCategories = (categories) ->
  forEachCategoriesField categories, (fieldId, field, cat) ->
    delete field.optional
removeRequiredPropertyFromCategories(entityCategories)
# Entities don't need the class parameter since they reference the typology.
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
    collectionType: 'Typologies'
# Despite having the "entity" field on lots, when a new entity is created it is rendered
# reactively and without a lot reference it will fail.
  lot:
    label: 'Lot'
    type: String
    index: true
    collectionType: 'Lots'
    # Not necessary for PATHWAY type.
    optional: true
  parameters:
    label: 'Parameters'
    type: EntityParametersSchema
  # Necessary to allow required fields within.
    optional: false
    defaultValue: {}
  project: projectSchema

@Entities = new Meteor.Collection 'entities'
Entities.attachSchema(EntitySchema)
Entities.allow(Collections.allowAll())

Entities.getFlattened = (id) ->
  entity = Entities.findOne(id)
  Entities.mergeTypology(entity)
  entity

Entities.getAllFlattenedInProject = (filter) ->
  entities = Entities.findByProject().fetch()
  if filter
    entities = _.filter entities, filter
  _.map entities, (entity) -> Entities.getFlattened(entity._id)

Entities.mergeTypology = (entity) ->
  typologyId = entity.typology
  if typologyId?
    typology = Typologies.findOne(typologyId)
    Entities.mergeTypologyObj(entity, typology)
  entity

Entities.mergeTypologyObj = (entity, typology) ->
  if typology?
    entity._typology = typology
    Typologies.mergeDefaults(typology)
    entity.parameters ?= {}
    Setter.defaults(entity.parameters, typology.parameters)
    Typologies.filterParameters(entity)
  entity

Entities.findByProject = (projectId) -> SchemaUtils.findByProject(Entities, projectId)

Entities.findByTypology = (typologyId) -> Entities.find({typology: typologyId})

Entities.findByTypologyClass = (typologyClass, projectId) ->
  typologies = Typologies.findByClass(typologyClass, projectId)
  entities = []
  _.each typologies, (typology) ->
    _.each Entities.findByTypology(typology._id), (entity) ->
      entities.push(entity)
  entities

Entities.getTypologyClass = (id) ->
  typologyId = Entities.findOne(id).typology
  Typologies.getTypologyClass(typologyId) if typologyId?

Entities.allowsMultipleDisplayModes = (id) ->
  typologyClass = Entities.getTypologyClass(id)
  displayMode = TypologyClasses[typologyClass].displayMode
  !(displayMode? && (displayMode == false || !Types.isArray(displayMode)))

# Listen for changes to Entities or Typologies and refresh reports.
_reportRefreshSubscribed = false
subscribeRefreshReports = ->
  return if _reportRefreshSubscribed
  _.each [
    {collection: Entities, observe: ['added', 'changed', 'removed']}
    {collection: Typologies, observe: ['changed']}
  ], (args) ->
    collection = args.collection
    shouldRefresh = false
    refreshReport = ->
      if shouldRefresh
        # TODO(aramk) Report refreshes too soon and geo entity is being reconstructed after an
        # update. This delay is a quick fix, but we should use promises.
        setTimeout (-> PubSub.publish('report/refresh')), 1000
    cursor = collection.find()
    _.each _.unique(args.observe), (methodName) ->
      observeArgs = {}
      observeArgs[methodName] = refreshReport
      cursor.observe(observeArgs)
    # TODO(aramk) Temporary solution to prevent refreshing due to added callback firing for all
    # existing docs.
    shouldRefresh = true
    _reportRefreshSubscribed = true
# Refresh only if a report has been rendered before.
PubSub.subscribe 'report/rendered', subscribeRefreshReports

####################################################################################################
# AZIMUTH ARRAY ENERGY DEMAND
####################################################################################################

getModifiedDocWithDeps = (doc, modifier, depParamIds) ->
  isUpdating = modifier?
  hasDependencyUpdates = false
  if isUpdating
    # Add modified values to doc to ensure we use the latest values in calculations.
    fullDoc = Collections.simulateModifierUpdate(doc, modifier)
    # If no dependencies are being updated, the energy demands won't change, so we can quit early.
    hasDependencyUpdates = _.some depParamIds, (fieldId) ->
      modifier.$set?[fieldId]? || modifier.$unset?[fieldId]
  else
    fullDoc = Setter.clone(doc)
  {fullDoc: fullDoc, hasDependencyUpdates: hasDependencyUpdates}

applyModifierSet = (doc, modifier, $set) ->
  isUpdating = modifier?
  modifier ?= {}
  $existingSet = modifier.$set
  if $existingSet?
    Setter.merge($existingSet, $set)
  else
    modifier.$set = $set
  unless isUpdating
    Setter.merge(doc, Collections.simulateModifierUpdate(doc, modifier))
  # Remove parameters in the new $set that are present in the original $unset.
  $unset = modifier.$unset
  if $unset
    _.each $set, (value, fieldId) ->
      delete $unset[fieldId]
  modifier

Typologies.calcOutputFromAzimuth = (array, azimuth) ->
  input = azimuth % 360
  Maths.calcUniformBinValue(array, input, 360)

azimuthArrayDependencyFieldIds = ['parameters.space.cfa', 'parameters.orientation.azimuth',
  'parameters.orientation.eq_azmth_h', 'parameters.orientation.eq_azmth_c']

# A queue of entity IDs which should be updated with blank modifiers so their azimuth-based values
# are updated. This must take place after the typology is modified so that it inherits the updated
# values.
entityUpdateQueue = []
updateQueuedEntities = ->
  while entityUpdateQueue.length > 0
    entityId = entityUpdateQueue.pop()
    Entities.update(entityId, {$set: {}})

# Update the energy demand based on the azimuth array.
updateAzimuthEnergyDemand = (userId, doc, fieldNames, modifier) ->
  isUpdating = modifier?
  depResult = getModifiedDocWithDeps(doc, modifier, azimuthArrayDependencyFieldIds)
  fullDoc = depResult.fullDoc
  isEntity = doc.typology?
  return unless depResult.hasDependencyUpdates || isEntity
  Entities.mergeTypology(fullDoc) if isEntity
  eq_azmth_h = SchemaUtils.getParameterValue(fullDoc, 'parameters.orientation.eq_azmth_h')
  eq_azmth_c = SchemaUtils.getParameterValue(fullDoc, 'parameters.orientation.eq_azmth_c')
  azimuth = SchemaUtils.getParameterValue(fullDoc, 'parameters.orientation.azimuth') ? 0
  cfa = SchemaUtils.getParameterValue(fullDoc, 'parameters.space.cfa')
  return unless cfa? && azimuth?
  $set = {}
  items = [
    {array: eq_azmth_h, energyParamId: 'parameters.energy_demand.en_heat'}
    {array: eq_azmth_c, energyParamId: 'parameters.energy_demand.en_cool'}
  ]
  _.each items, (item) ->
    array = item.array
    array = if array then JSON.parse(array) else null
    return unless array?
    hasNullValue = _.some array, (value) -> value == null
    if !hasNullValue
      energyM2 = Typologies.calcOutputFromAzimuth(array, azimuth)
      $set[item.energyParamId] = energyM2 * cfa
  return if Object.keys($set).length == 0
  modifier = applyModifierSet(doc, modifier, $set)
  # If updating a typology, ensure all entities have their energy demand values updated as well.
  if isUpdating && !isEntity
    _.each Entities.find(typology: doc._id).fetch(), (entity) -> entityUpdateQueue.push(entity._id)
  modifier

Entities.before.insert(updateAzimuthEnergyDemand)
Entities.before.update(updateAzimuthEnergyDemand)
Typologies.before.insert(updateAzimuthEnergyDemand)
Typologies.before.update(updateAzimuthEnergyDemand)
Typologies.after.insert(updateQueuedEntities)
Typologies.after.update(updateQueuedEntities)

####################################################################################################
# BUILD TYPE
####################################################################################################

buildTypeDependencyFieldIds = ['parameters.financial.build_type',
  'parameters.general.subclass', 'parameters.space.gfa']

updateBuildType = (userId, doc, fileNames, modifier) ->
  depResult = getModifiedDocWithDeps(doc, modifier, buildTypeDependencyFieldIds)
  fullDoc = depResult.fullDoc
  Typologies.mergeDefaults(fullDoc)
  project = Projects.mergeDefaults(Projects.findOne(fullDoc.project))
  return unless depResult.hasDependencyUpdates
  build_type = SchemaUtils.getParameterValue(fullDoc, 'financial.build_type')
  subclass = SchemaUtils.getParameterValue(fullDoc, 'general.subclass')
  gfa = SchemaUtils.getParameterValue(fullDoc, 'space.gfa')
  $set = {}
  return unless build_type? && build_type != 'Custom' && subclass? && gfa?
  typologyClass = SchemaUtils.getParameterValue(fullDoc, 'general.class')
  field = SchemaUtils.getField('parameters.financial.build_type', Typologies)
  options = field?.classes[typologyClass]
  costParamId =
    options.getCostParamId(subclass: subclass, typologyClass: typologyClass, value: build_type)
  costParamValue = SchemaUtils.getParameterValue(project, costParamId)
  cost_ug_park = SchemaUtils.getParameterValue(project, 'financial.parking.cost_ug_park')
  parking_ug = SchemaUtils.getParameterValue(fullDoc, 'parking.parking_ug')
  parkingCost = if parking_ug? then cost_ug_park * parking_ug else 0
  $set['parameters.financial.cost_con'] = costParamValue * gfa + parkingCost
  applyModifierSet(doc, modifier, $set)

Typologies.before.insert(updateBuildType)
Typologies.before.update(updateBuildType)

####################################################################################################
# ASSOCIATION MAINTENANCE
####################################################################################################

# Remove the entity from the lot when removing the entity.
Collections.observe Entities,
  removed: (entity) ->
    lot = Lots.findByEntity(entity._id)
    Lots.update(lot._id, {$unset: {entity: null}}) if lot?

Collections.observe Lots,
  # TODO(aramk) This logic is still in the lotForm. Remove it from there first.
  changed: (newLot, oldLot) ->
    # Remove entity if it changes on the lot.
    oldId = oldLot.entity
    if oldId && oldId != newLot.entity
      Entities.remove(oldId)
  removed: (lot) ->
    # Remove the entity when the lot is removed.
    entityId = lot.entity
    Entities.remove(entityId) if lot.entity?

Collections.observe Typologies,
  changed: (newTypology, oldTypology) ->
    # Changing the class of the lots with the typology when changing it on the typology.
    classParamId = 'parameters.general.class'
    newClass = SchemaUtils.getParameterValue(newTypology, classParamId)
    oldClass = SchemaUtils.getParameterValue(oldTypology, classParamId)
    if newClass != oldClass
      lots = Lots.findByTypology(newTypology._id)
      console.debug('Updating class of Lots', lots, 'from', oldClass, 'to', newClass)
      _.each lots, (lot) ->
        modifier = {$set: {}}
        modifier.$set[classParamId] = newClass
        # TODO(aramk) For some reason, even if this is delayed, the models will switch back despite
        # a successful update.
        Lots.update lot._id, modifier, (err, result) ->
          console.debug('Lots update', err, result)
  removed: (typology) ->
    # Remove entities when the typology is removed.
    _.each Entities.findByTypology(typology._id).fetch(), (entity) -> Entities.remove(entity._id)
