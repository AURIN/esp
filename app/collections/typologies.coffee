####################################################################################################
# SCHEMA OPTIONS
####################################################################################################

COLLECTIONS_DEBUG = false

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
  daysWeek: 'days/week'
  deg: 'degrees'
  dwellings: 'dwellings'
  floors: 'floors'
  GJyear: 'GJ/year'
  GJOccupantYear: 'GJ/occupant/year'
  ha: 'ha'
  hrsDay: 'hours/day'
  hrsYear: 'hours/year'
  jobs: 'jobs'
  kgco2: 'kg CO_2-e'
  kgco2day: 'kg CO_2-e/day'
  kgco2kWh: 'kg CO_2-e/kWh'
  kgco2km: 'kg CO_2-e/km'
  kgco2m2: 'kg CO_2-e/m^2'
  kgco2MJ: 'kg CO_2-e/MJ'
  kgco2space: 'kg CO_2-e/space'
  kgco2year: 'kg CO_2-e/year'
  kW: 'kW'
  kWh: 'kWh'
  kWhday: 'kWh/day'
  kWhyear: 'kWh/year'
  kLyear: 'kL/year'
  kLOccupantYear: 'kL/occupant/year'
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
  tripsdwelling: 'trips/day'
  tripsyear: 'trips/year'
  vehicles: 'vehicles'
  weeksYear: 'weeks/year'
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
  # Category-wide classes definition.
  catClasses = cat.classes
  _.each cat.items, (item, itemId) ->
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
      if catClasses
        fieldSchema.classes ?= Setter.clone(catClasses)
      # If defaultValue is used, put it into "classes" to prevent SimpleSchema from storing this
      # value in the doc. We want to inherit this value at runtime for all classes, but not
      # persist it in multiple documents in case we want to change it later in the schema.
      defaultValue = fieldSchema.defaultValue
      if defaultValue?
        classes = fieldSchema.classes
        if classes
          _.each classes, (classOptions, name) ->
            classOptions.defaultValue = defaultValue
        else
          fieldSchema.classes = {ALL: {defaultValue: defaultValue}}
        delete fieldSchema.defaultValue
    catSchemaFields[itemId] = fieldSchema
  if COLLECTIONS_DEBUG
    console.log('catSchemaFields', catSchemaFields)
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
  if COLLECTIONS_DEBUG
    console.log('catsFields', catsFields)
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

latitudeSchema =
  label: 'Latitude'
  type: Number
  decimal: true
  units: Units.deg

longitudeSchema =
  label: 'Longitude'
  type: Number
  decimal: true
  units: Units.deg

elevationSchema =
  type: Number
  decimal: true
  desc: 'Elevation from ground-level to the base of this entity.'
  units: Units.m
  optional: true

localCoordSchema =
  type: Number
  decimal: true
  units: Units.m

PositionSchema = new SimpleSchema
  latitude: latitudeSchema
  longitude: longitudeSchema
  elevation: elevationSchema

VertexSchema = new SimpleSchema
  x:
    type: Number
    decimal: true
  y:
    type: Number
    decimal: true
  z:
    type: Number
    decimal: true

descSchema =
  label: 'Description'
  type: String

####################################################################################################
# PROJECT SCHEMA DEFINITION
####################################################################################################

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
      elec_mj:
        label: 'Carbon per MJ - Electricity'
        type: Number
        decimal: true
        units: Units.kgco2MJ
        # We must divide by 3.6 since MJ is in the denominator.
        calc: 'MJ_TO_KWH($operating_carbon.elec)'
      gas_mj:
        label: 'Carbon per MJ - Gas'
        type: Number
        decimal: true
        units: Units.kgco2MJ
        # We must divide by 3.6 since MJ is in the denominator.
        calc: 'MJ_TO_KWH($operating_carbon.gas)'
      vkt:
        label: 'Carbon per vehicle km travelled'
        type: Number
        decimal: true
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
      price_usage_elec_tariff:
        label: 'Electricity Feed-In Price per kWh'
        type: Number
        decimal: true
        units: Units.$kWh
        defaultValue: 0.4
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
        units: Units.$MJ
        defaultValue: 0.024
      price_supply_cogen:
        label: 'Cogen/Trigen Supply Charge'
        type: Number
        decimal: true
        units: Units.$day
        defaultValue: 0
      price_usage_cogen:
        label: 'Cogen/Trigen Usage Charge'
        type: Number
        decimal: true
        units: Units.$MJ
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
      avg_annual_rainfall:
        label: 'Average Annual Rainfall'
        units: Units.mm
        type: Number
        decimal: true
        defaultValue: 700
      rain_sys_eff:
        label: 'Rainwater System Efficiency'
        type: Number
        decimal: true
        defaultValue: 0.8
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
      mixed_use:
        items:
          std:
            label: 'Single House - Standard'
            type: Number
            units: Units.$m2
            defaultValue: 2090
          hq:
            label: 'Single House - Standard'
            type: Number
            units: Units.$m2
            defaultValue: 2819
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
            defaultValue: -2
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
      cogen:
        label: 'Cogen/Trigen'
        items:
          spec:
            label: 'Plant Specifications'
            items:
              plant_size:
                desc: 'Power plant size.'
                label: 'Power Plant Size'
                type: Number
                decimal: true
                units: Units.kW
                defaultValue: 50
              plant_eff:
                desc: 'Power plant efficiency.'
                label: 'Power Plant Efficiency'
                type: Number
                decimal: true
                defaultValue: 0.35
              cop_heat:
                desc: 'Coefficient of performance of the heat exchanger.'
                label: 'COP (Heat exchanger)'
                type: Number
                decimal: true
                defaultValue: 0.8
              cop_cool:
                desc: 'Coefficient of performance of the absorbtion chiller.'
                label: 'COP (Absorbtion chiller)'
                type: Number
                decimal: true
                defaultValue: 0.7
          operation:
            label: 'Plant Operation'
            items:
              op_hrs_day:
                desc: 'Power plant operating hours per day.'
                label: 'Operating Hours per Day'
                type: Number
                units: Units.hrsDay
                defaultValue: 12
              op_days_wk:
                desc: 'Power plant operating days per week.'
                label: 'Operating Days per Week'
                type: Number
                units: Units.daysWeek
                defaultValue: 7
              op_wks_year:
                desc: 'Power plant operating weeks per year.'
                label: 'Operating Weeks per Year'
                type: Number
                units: Units.weeksYear
                defaultValue: 52
              op_hrs_year:
                desc: 'Power plant operating hours per year.'
                label: 'Operating Hours per Year'
                type: Number
                units: Units.hrsYear
                calc: '$energy.cogen.operation.op_hrs_day * $energy.cogen.operation.op_days_wk * $energy.cogen.operation.op_wks_year'
          output:
            label: 'Plant Output'
            items:
              elec_output:
                desc: 'Power plant electricity generated.'
                label: 'Electricity Output'
                type: Number
                units: Units.MJyear
                calc: 'KWH_TO_MJ($energy.cogen.spec.plant_size) * $energy.cogen.spec.plant_eff * $energy.cogen.operation.op_hrs_year'
              prim_th_en:
                desc: 'Power plant primary thermal energy generated.'
                label: 'Primary Thermal Energy Generated'
                type: Number
                units: Units.MJyear
                calc: 'KWH_TO_MJ($energy.cogen.spec.plant_size) * (1 - $energy.cogen.spec.plant_eff) * $energy.cogen.operation.op_hrs_year'
              th_en_heat:
                desc: 'Thermal energy available for space and water heating.'
                label: 'Thermal Energy - Heating'
                type: Number
                units: Units.MJyear
                calc: '$energy.cogen.thermal.th_en_cap * $energy.cogen.thermal.prpn_th_en_h * $energy.cogen.spec.cop_heat'
              th_en_cool:
                desc: 'Thermal energy available for space cooling.'
                label: 'Thermal Energy - Cooling'
                type: Number
                units: Units.MJyear
                calc: '$energy.cogen.thermal.th_en_cap * (1 - $energy.cogen.thermal.prpn_th_en_h) * $energy.cogen.spec.cop_cool'
          input:
            label: 'Plant Input'
            items:
              gas_en_input:
                desc: 'Energy required for power plant operation.'
                label: 'Energy Input Requirment (Gas)'
                type: Number
                units: Units.MJyear
                calc: '$energy.cogen.output.elec_output / $energy.cogen.spec.plant_eff'
          thermal:
            label: 'Thermal Energy Use'
            items:
              prpn_heat_cap:
                desc: 'Proportion of primary thermal energy capturable for precinct thermal energy requirements.'
                label: 'Proportion of Thermal Energy Capturable'
                type: Number
                decimal: true
                defaultValue: 0.75
              th_en_cap:
                desc: 'Proportion of primary thermal energy captured.'
                label: 'Thermal Energy Captured'
                type: Number
                units: Units.MJyear
                calc: '$energy.cogen.thermal.prpn_heat_cap * $energy.cogen.output.prim_th_en'
              prpn_th_en_h:
                desc: 'Proportion of recovered thermal energy used as hot thermal, versus cool thermal.'
                label: 'Proportion of Thermal Energy for Heating'
                type: Number
                decimal: true
                defaultValue: 0.5
          operating_carbon:
            label: 'Operating Carbon'
            items:
              co2_op_total:
                desc: 'Power plant operating carbon.'
                label: 'CO2 - Total Plant'
                type: Number
                units: Units.kgco2year
                calc: '$energy.cogen.input.gas_en_input * $operating_carbon.gas_mj'
              prpn_co2_e:
                desc: 'Proportion of the power plant\'s CO2 attributable to electricity generation.'
                label: 'Proportion CO2 - Electricity'
                type: Number
                decimal: true
                calc: -> calcEnergyCogenC02.call(@, 'elec')
              prpn_co2_h:
                desc: 'Proportion of the power plant\'s CO2 attributable to hot thermal energy generation.'
                label: 'Proportion CO2 - Hot Thermal'
                type: Number
                decimal: true
                calc: -> calcEnergyCogenC02.call(@, 'heat')
              prpn_co2_c:
                desc: 'Proportion of the power plant\'s CO2 attributable to cold thermal energy generation.'
                label: 'Proportion CO2 - Cold Thermal'
                type: Number
                decimal: true
                calc: -> calcEnergyCogenC02.call(@, 'cool')
              co2_op_e_cogen:
                desc: 'CO2 from the power plant generating electricity.'
                label: 'CO2 - Electricity'
                type: Number
                units: Units.kgco2year
                calc: '$energy.cogen.operating_carbon.prpn_co2_e * $energy.cogen.operating_carbon.co2_op_total'
              co2_op_h_cogen:
                desc: 'CO2 from the power plant generating hot thermal energy.'
                label: 'CO2 - Hot Thermal'
                type: Number
                units: Units.kgco2year
                calc: '$energy.cogen.operating_carbon.prpn_co2_h * $energy.cogen.operating_carbon.co2_op_total'
              co2_op_c_cogen:
                desc: 'CO2 from the power plant generating cold thermal energy.'
                label: 'CO2 - Cold Thermal'
                type: Number
                units: Units.kgco2year
                calc: '$energy.cogen.operating_carbon.prpn_co2_c * $energy.cogen.operating_carbon.co2_op_total'
              co2_int_elec:
                desc: 'CO2 intensity of power plant\'s electricity.'
                label: 'CO2 Intensity - Electricity'
                type: Number
                decimal: true
                units: Units.kgco2MJ
                calc: '$energy.cogen.operating_carbon.co2_op_e_cogen / $energy.cogen.output.elec_output'
              co2_int_heat:
                desc: 'CO2 intensity of power plant\'s hot thermal energy.'
                label: 'CO2 Intensity - Hot Thermal'
                type: Number
                decimal: true
                units: Units.kgco2MJ
                calc: '$energy.cogen.operating_carbon.co2_op_h_cogen / $energy.cogen.output.th_en_heat'
              co2_int_cool:
                desc: 'CO2 intensity of power plant\'s cold thermal energy.'
                label: 'CO2 Intensity - Cold Thermal'
                type: Number
                decimal: true
                units: Units.kgco2MJ
                calc: '$energy.cogen.operating_carbon.co2_op_c_cogen / $energy.cogen.output.th_en_cool'
  parking:
    label: 'Parking'
    items:
      prk_area_veh:
        label: 'Parking Area per Vehicle'
        type: Number
        units: Units.m2vehicle
        defaultValue: 23
      co2_ug:
        label: 'CO2 per Underground Parking Space'
        type: Number
        units: Units.kgco2space
        defaultValue: 5395
  transport:
    label: 'Transport'
    items:
      trips:
        label: 'Daily Trips per Dwelling'
        desc: 'Mean daily trips per dwelling.'
        type: Number
        decimal: true
        units: Units.tripsdwelling
        defaultValue: 10.7
      age:
        label: 'Mean Age'
        desc: 'Mean resident age.'
        type: Number
        decimal: true
        units: Units.years
        defaultValue: 38
      gender:
        label: 'Share Female Residents'
        desc: 'Share of female residents.'
        type: Number
        decimal: true
        defaultValue: 0.52
      hhsize:
        label: 'Household Size'
        desc: 'Mean household size.'
        type: Number
        decimal: true
        units: Units.people
        defaultValue: 2.6
      totalvehs:
        label: 'Vehicles per Household'
        desc: 'Mean vehicles per household.'
        type: Number
        decimal: true
        units: Units.vehicles
        defaultValue: 1.8
      hhinc_grp:
        label: 'Household Income Group'
        desc: 'Mean household income earning group. Range is 1 to 5 with 5 earning the highest income.'
        type: Number
        decimal: true
        defaultValue: 3.3
      distctr:
        label: 'Distance to Activity Centre'
        desc: 'Mean street network distance to the nearest CBD or major centre.'
        type: Number
        decimal: true
        units: Units.km
        defaultValue: 6.3
      railprox:
        label: 'Proximity to Rail'
        desc: 'Proximity band measuring street network distance to nearest train station or tram corridor.'
        type: String
        units: Units.km
        defaultValue: 'railgt_1600'
        allowedValues: Object.keys(VktRailTypes)
      distbus:
        label: 'Distance to Bus Stop'
        desc: 'Mean street network distance to the nearest standard bus stop.'
        type: Number
        decimal: true
        units: Units.km
        defaultValue: 0.4
      lum_index:
        label: 'LUM Index'
        desc: 'Mean land use mix within a 1600m street network walking catchment. Range is 0 to 1 with 1 being the most mixed.'
        type: Number
        decimal: true
        defaultValue: 0.38
      density:
        label: 'Density'
        desc: 'Mean housing density within a 1600m street network walking catchment.'
        type: Number
        decimal: true
        defaultValue: 21.8
      towork:
        label: 'Share of Work Trips'
        desc: 'Share of trips made as commuting trips to work.'
        type: Number
        decimal: true
        defaultValue: 0.22

@ProjectParametersSchema = createCategoriesSchema
  categories: projectCategories

ProjectSchema = new SimpleSchema
  name:
    label: 'Name'
    type: String
    index: true
    unique: false
  desc: descSchema
  author:
    type: String
    index: true
  parameters:
    label: 'Parameters'
    type: ProjectParametersSchema
    defaultValue: {}
  dateModified:
    label: 'Date Modified'
    type: Date
  userModified:
    label: 'User Modified'
    type: String
    # Necessary to allow the collection hook to run and provide the value at runtime.
    optional: true
  isTemplate:
    label: 'Template?'
    type: Boolean
    desc: 'Template Projects can be duplicated by all users.'
    defaultValue: false
  isPublic:
    label: 'Public?'
    desc: 'Public Projects can be viewed by anyone without logging in. Only the author can modify them.'
    type: Boolean
    defaultValue: false

@Projects = new Meteor.Collection 'projects', schema: ProjectSchema
Projects.attachSchema(ProjectSchema)
Projects.ParametersSchema = ProjectParametersSchema
AccountsUtil.addCollectionAuthorization Projects,
  # A user has access to their own projects as well as any templates.
  userSelector: (args) -> {$or: [{author: args.username}, {isTemplate: true}]}
AccountsUtil.setUpCollectionAllow(Projects)

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
  SchemaUtils.unflattenParameters(values, false)

Projects.mergeDefaults = (model) ->
  defaults = Projects.getDefaultParameterValues()
  mergeDefaultParameters(model, defaults)

# Template and Public Projects

Collections.addValidation Projects, (doc) ->
  isAdmin = AccountsUtil.isAdmin(@userId)
  if doc.isTemplate && !isAdmin
    throw new Error('Only admin user can create template projects.')

##################################################################################################
# PROJECT DATE
##################################################################################################

# Updating project or models in the project will update the modified date of a project.

getCurrentDate = -> moment().toDate()

Projects.before.insert (userId, doc) ->
  doc.dateModified = getCurrentDate()

Projects.before.update (userId, doc, fieldNames, modifier) ->
  modifier.$set ?= {}
  delete modifier.$unset?.dateModified
  modifier.$set.dateModified = getCurrentDate()

####################################################################################################
# TYPOLOGY SCHEMA DECLARATION
####################################################################################################

TypologyClasses = Object.freeze({
  RESIDENTIAL:
    name: 'Residential'
    color: '#3182bd' # Blue
    abbr: 'r'
    # subclasses: ['Single House', 'Attached House', 'Walkup', 'High Rise']
    subclasses:
      'Single House':
        color: '#3182bd'
      'Attached House':
        color: '#278db9'
      'Walkup':
        color: '#1692b1'
      'High Rise':
        color: '#407fc6'
  COMMERCIAL:
    name: 'Commercial'
    color: '#e34236'
    abbr: 'c'
    subclasses:
      'Retail':
        color: '#e34236'
      'Office':
        color: '#ec483d'
      'Hotel':
        color: '#e02a2e'
      'Supermarket':
        color: '#eb3232'
      'Restaurant':
        color: '#e53b3b'
  INSTITUTIONAL:
    name: 'Institutional'
    color: '#ffae00' # Orange
    abbr: 'i'
    subclasses:
      'School':
        color: '#ffae00'
      'Tertiary':
        color: '#ffd200'
      'Hospital':
        color: '#ffc63d'
      'Public':
        color: '#e4ff00'
  MIXED_USE:
    name: 'Mixed Use'
    color: '#756bb1' # Purple
    abbr: 'mu'
  OPEN_SPACE:
    name: 'Open Space'
    color: '#31a354' # Green
    abbr: 'os'
    displayMode: false
  PATHWAY:
    name: 'Pathway'
    color: '#333'
    abbr: 'pw'
    displayMode: 'line'
    canAllocateToLot: false
    subclasses: ['Freeway', 'Highway', 'Street', 'Footpath', 'Bicycle Path']
  ASSET:
    name: 'Asset'
    color: '#999' # Grey
})

BuildingClasses = Object.freeze({
  RESIDENTIAL: {}
  COMMERCIAL: {}
  MIXED_USE: {}
  INSTITUTIONAL: {}
})

extendClassMap = (args, map) ->
  unless map then throw new Error('Map not defined.')
  args = if args then Setter.clone(args) else {}
  Setter.merge(Setter.clone(map), args)
extendBuildingClasses = (args) -> extendClassMap(args, BuildingClasses)
extendClassesWithDefault = (classArgs, defaultValue) ->
  _.each classArgs, (args, classId) ->
    args.defaultValue = defaultValue
  classArgs

LandClasses = Object.freeze(extendClassMap(OPEN_SPACE: {}, BuildingClasses))

extendLandClasses = (args) -> extendClassMap(args, LandClasses)

isNonResidentialBuildingClass = (typologyClass) ->
  !!{COMMERCIAL: true, MIXED_USE: true, INSTITUTIONAL: true}[typologyClass]

ClassNames = Object.keys(TypologyClasses)
TypologyTypes = ['Basic', 'Efficient', 'Advanced']
ENERGY_SOURCE_ELEC = 'Electricity'
ENERGY_SOURCE_GAS = 'Gas'
ENERGY_SOURCE_COGEN = 'Cogen/Trigen'
EnergySources = [ENERGY_SOURCE_ELEC, ENERGY_SOURCE_GAS, ENERGY_SOURCE_COGEN]
EnergySources.ELEC = ENERGY_SOURCE_ELEC
EnergySources.GAS = ENERGY_SOURCE_GAS
EnergySources.COGEN = ENERGY_SOURCE_COGEN

ResidentialSubclasses = Object.keys(TypologyClasses.RESIDENTIAL.subclasses)
CommercialSubclasses = Object.keys(TypologyClasses.COMMERCIAL.subclasses)
InstitutionalSubclasses = Object.keys(TypologyClasses.INSTITUTIONAL.subclasses)
PathwaySubclasses = TypologyClasses.PATHWAY.subclasses

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
MixedUseBuildTypes =
  'Standard Quality Build': 'std'
  'High Quality Build': 'hq'
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
calcEnergyC02 = (sourceParamId, energyParamId, cogenIntensityParamId) ->
  src = @param(sourceParamId)
  en = @param(energyParamId)
  return null unless src? and en?
  prpn_elec_scheme = @param('energy_demand.prpn_elec_scheme')
  if src == ENERGY_SOURCE_ELEC
    (en * @KWH_TO_MJ(@param('operating_carbon.elec')) * prpn_elec_scheme) +
      (en * @param('energy.cogen.operating_carbon.co2_int_elec') * (1 - prpn_elec_scheme))
  else if src == ENERGY_SOURCE_GAS
    en * @KWH_TO_MJ(@param('operating_carbon.gas'))
  else if src == ENERGY_SOURCE_COGEN
    en * @param('energy.cogen.operating_carbon.' + cogenIntensityParamId)

calcEnergyCogenC02 = (type) ->
  elec_output = @param('energy.cogen.output.elec_output')
  elec_rate = @calc('$operating_carbon.elec_mj')
  gas_rate = @calc('$operating_carbon.gas_mj')
  th_en_heat = @param('energy.cogen.output.th_en_heat')
  th_en_cool = @param('energy.cogen.output.th_en_cool')

  elec_emissions = elec_output * elec_rate
  heat_emissions = th_en_heat / 0.75 * gas_rate
  cool_emissions = th_en_cool / 4 * elec_rate

  emissionsMap = {elec: elec_emissions, heat: heat_emissions, cool: cool_emissions}
  emissions = emissionsMap[type]
  unless emissions?
    throw new Error('No emissions for type: ' + type)

  total = elec_emissions + heat_emissions + cool_emissions
  if total == 0
    return 0
  emissions / total

calcEnergyCost = (source, suffix) ->
  supply_price = @param('utilities.price_supply_' + suffix)
  usage_price = @param('utilities.price_usage_' + suffix)
  if source == ENERGY_SOURCE_GAS
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
  if source == ENERGY_SOURCE_ELEC
    usage_cost += en_app * usage_price
    usage_cost += en_light * usage_price
    usage_cost -= 365 * pv_output * size_pv * usage_price
  365 * supply_price + usage_cost

calcEnergyCost2 = (suffix, demand) ->
  demand ?= 'en_' + suffix
  if @param('energy_demand.en_' + suffix) == 0
    0
  else
    365 * @param('utilities.price_supply_' + suffix) + @param('energy_demand.' + demand) *
        @KWH_TO_MJ(@param('utilities.price_usage_' + suffix))

calcElecCost = ->
  en_elec_scheme = @param('energy_demand.en_elec_scheme')
  if en_elec_scheme == 0
    return 0
  usageParamId = if en_elec_scheme < 0 then 'price_usage_elec_tariff' else 'price_usage_elec'
  365 * @param('utilities.price_supply_elec') + en_elec_scheme *
      @KWH_TO_MJ(@param('utilities.' + usageParamId))

calcEnergyWithIntensityCost = (suffix, shortSuffix) ->
  supply_price = @param('utilities.price_supply_' + suffix)
  usage_price = @KWH_TO_MJ(@param('utilities.price_usage_' + suffix))
  usage_cost = @param('energy_demand.en_use_' + shortSuffix) * usage_price
  365 * supply_price + usage_cost

calcLandPrice = ->
  typologyClass = Entities.getTypologyClass(@model)
  abbr = TypologyClasses[typologyClass].abbr
  return unless abbr?
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
        classes: RESIDENTIAL: {}
      type:
        type: String
        desc: 'Version of the subclass.'
        allowedValues: TypologyTypes
        classes: RESIDENTIAL: {}
  space:
    label: 'Space'
    items:
      geom_2d:
        label: '2D Geometry'
        type: String
        desc: '2D footprint geometry of the typology.'
        classes: extendBuildingClasses
          # RESIDENTIAL: {optional: false}
          # COMMERCIAL: {optional: false}
          # INSTITUTIONAL: {optional: false}
          # MIXED_USE: {optional: false}
          ASSET: {}
          # Pathway typologies don't have geometry - it is defined in the entities - so this is
          # optional.
          PATHWAY: {}
      geom_3d:
        label: '3D Geometry'
        type: String
        desc: '3D mesh representing the typology.'
        classes: extendBuildingClasses
          ASSET: {}
      geom_2d_filename:
        label: '2D Geometry Filename'
        type: String
        desc: 'The name of the file representing the 2D geometry.'
      geom_3d_filename:
        label: '3D Geometry Filename'
        type: String
        desc: 'The name of the file representing the 3D geometry.'
      position:
        items:
          latitude: extendSchema latitudeSchema, {classes: {ASSET: {}}}
          longitude: extendSchema longitudeSchema, {classes: {ASSET: {}}}
          elevation: extendSchema elevationSchema, {classes: {ASSET: {}}}
      offset:
        items:
          northern: extendSchema localCoordSchema,
            label: 'Northern Offset'
            desc: 'The offset distance in the northern direction from the centroid of the Lot.'
          eastern: extendSchema localCoordSchema,
            label: 'Eastern Offset'
            desc: 'The offset distance in the eastern direction from the centroid of the Lot.'
      lotsize: extendSchema areaSchema,
        label: 'Lot Size'
        calc: ->
          # If the model is a typology, it doesn't have a lot yet, so no lotsize.
          id = @model._id
          entity = Entities.findOne(id)
          unless entity then return null
          lot = Lots.findByEntity(id)
          typologyClass = Entities.getTypologyClass(entity)
          # Assets don't have lots.
          if typologyClass == 'ASSET' then return 0
          unless lot
            throw new Error('Lot not found for entity.')
          calcArea(lot._id)
      extland: extendSchema areaSchema,
        label: 'Extra Land'
        desc: 'Area of the land parcel not covered by the structural improvement.'
        calc: ->
          id = @model._id
          entity = Entities.findOne(id)
          unless entity then return null
          typologyClass = Entities.getTypologyClass(entity)
          # Assets don't have lots.
          if typologyClass == 'ASSET' then return 0
          @calc('$space.lotsize - $space.fpa')
      fpa: extendSchema areaSchema,
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
      gfa:
        label: 'Gross Floor Area'
        desc: 'Gross floor area of all the rooms in the typology.'
        type: Number
        decimal: true
        units: Units.m2
        classes: extendBuildingClasses
          MIXED_USE: false
      gfa_r:
        label: 'Residential Gross Floor Area'
        type: Number
        decimal: true
        units: Units.m2
        classes: MIXED_USE: {}
      gfa_c:
        label: 'Commercial Gross Floor Area'
        type: Number
        decimal: true
        units: Units.m2
        classes: MIXED_USE: {}
      gfa_t:
        label: 'Gross Floor Area'
        desc: 'Gross floor area of all the rooms in the typology.'
        type: Number
        decimal: true
        units: Units.m2
        calc: ->
          typologyClass = Entities.getTypologyClass(@model)
          if typologyClass == 'MIXED_USE'
            @param('space.gfa_r') + @param('space.gfa_c')
          else
            @param('space.gfa')
      cfa:
        label: 'Conditioned Floor Area'
        desc: 'Total conditioned area of the typology.'
        type: Number
        decimal: true
        units: Units.m2
        classes: RESIDENTIAL: {}
      storeys:
        label: 'Storeys'
        desc: 'Number of floors/storeys in the typology.'
        type: Number
        units: Units.floors
        classes: extendBuildingClasses()
      height: extendSchema heightSchema,
        classes: extendBuildingClasses(ASSET: {})
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
        classes: PATHWAY: {}
      area:
        label: 'Total Path Area'
        type: Number
        decimal: true
        units: Units.m2
        calc: '$space.width * $space.length'
        classes: PATHWAY: {}
      plot_ratio:
        label: 'Plot Ratio'
        desc: 'The building footprint area divided by the lot size.'
        type: Number
        decimal: true
        calc: '$space.gfa_t / $space.lotsize'
      occupants:
        label: 'No. Occupants'
        desc: 'Number of occupants in the typology.'
        type: Number
        units: Units.people
        classes:
          RESIDENTIAL: {}
          MIXED_USE: {}
      job_intensity:
        desc: 'Number of jobs per square metre of commercial floorspace.'
        label: 'Job Intensity'
        type: Number
        decimal: true
        units: Units.m2job
        classes:
          COMMERCIAL: {defaultValue: 20}
          INSTITUTIONAL: {defaultValue: 20}
          MIXED_USE: {defaultValue: 20}
      jobs:
        desc: 'Number of jobs in the commerical building.'
        label: 'Number of Jobs'
        type: Number
        units: Units.jobs
        calc: '$space.gfa_t / $space.job_intensity'
        classes:
          COMMERCIAL: {}
          INSTITUTIONAL: {}
          MIXED_USE: {}
      num_0br:
        label: 'Dwellings - Studio'
        desc: 'Number of studio units in the typology.'
        type: Number
        units: Units.dwellings
        classes:
          RESIDENTIAL: {}
          MIXED_USE: {}
      num_1br:
        label: 'Dwellings - 1 Bedroom'
        desc: 'Number of 1 bedroom units in the typology.'
        type: Number
        units: Units.dwellings
        classes:
          RESIDENTIAL: {}
          MIXED_USE: {}
      num_2br:
        label: 'Dwellings - 2 Bedroom'
        desc: 'Number of 2 bedroom units in the typology.'
        type: Number
        units: Units.dwellings
        classes:
          RESIDENTIAL: {}
          MIXED_USE: {}
      num_3plus:
        label: 'Dwellings - 3 Bedroom Plus'
        desc: 'Number of 3 bedroom units in the typology.'
        type: Number
        units: Units.dwellings
        classes:
          RESIDENTIAL: {}
          MIXED_USE: {}
      dwell_tot:
        label: 'Dwellings - Total'
        desc: 'Number of total dwellings in the typology.'
        type: Number
        units: Units.dwellings
        calc: '$space.num_0br + $space.num_1br + $space.num_2br + $space.num_3plus'
      dwell_dens:
        label: 'Dwelling - Density'
        desc: 'Total number of dwellings divided by the lot size.'
        type: Number
        decimal: true
        units: Units.dwellings + '/' + Units.ha
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
      src_heat:
        label: 'Heating Source'
        desc: 'Energy source in the typology used for heating.'
        type: String
        allowedValues: EnergySources
        classes: RESIDENTIAL: {defaultValue: ENERGY_SOURCE_ELEC}
      en_heat:
        label: 'Heating'
        desc: 'Energy required for heating the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: ->
          therm_en_heat = @param('energy_demand.therm_en_heat')
          if @param('energy_demand.src_heat') == ENERGY_SOURCE_COGEN
            therm_en_heat
          else
            therm_en_heat / @param('energy_demand.cop_heat')
        classes: RESIDENTIAL: {}
      src_cool:
        label: 'Cooling Source'
        desc: 'Energy source in the typology used for cooling.'
        type: String
        allowedValues: _.without(EnergySources, ENERGY_SOURCE_GAS)
        classes: RESIDENTIAL: {defaultValue: ENERGY_SOURCE_ELEC}
      en_cool:
        label: 'Cooling'
        desc: 'Energy required for cooling the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: ->
          therm_en_cool = @param('energy_demand.therm_en_cool')
          if @param('energy_demand.src_cool') == ENERGY_SOURCE_COGEN
            therm_en_cool
          else
            therm_en_cool / @param('energy_demand.eer_cool')
        classes: RESIDENTIAL: {}
      cop_heat:
        label: 'Coefficient of Performance (COP)'
        type: Number
        decimal: true
        classes: RESIDENTIAL: {defaultValue: 4}
      eer_cool:
        label: 'Energy Efficiency Rating (EER)'
        type: Number
        decimal: true
        classes: RESIDENTIAL: {defaultValue: 4}
      therm_en_heat:
        label: 'Thermal Heating Energy'
        units: Units.MJyear
        type: Number
        decimal: true
        classes: RESIDENTIAL: {}
      therm_en_cool:
        label: 'Thermal Cooling Energy'
        units: Units.MJyear
        type: Number
        decimal: true
        classes: RESIDENTIAL: {}
      en_light:
        label: 'Lighting'
        desc: 'Energy required for lighting the typology.'
        type: Number
        decimal: true
        units: Units.kWhyear
        classes: RESIDENTIAL: {}
      src_hwat:
        label: 'Hot Water Source'
        desc: 'Energy source in the typology used for hot water heating. Used to calculated CO2-e.'
        type: String
        allowedValues: EnergySources
        classes: RESIDENTIAL: {defaultValue: ENERGY_SOURCE_ELEC}
      en_hwat:
        label: 'Hot Water'
        desc: 'Energy required for hot water heating in the typology.'
        type: Number
        decimal: true
        units: Units.GJyear
        calc: ->
          therm_en_hwat = @param('energy_demand.therm_en_hwat')
          if @param('energy_demand.src_hwat') == ENERGY_SOURCE_COGEN
            therm_en_hwat
          else
            therm_en_hwat / @param('energy_demand.cop_hws')
        classes: RESIDENTIAL: {}
      therm_en_hwat:
        label: 'Hot Water Thermal'
        type: Number
        decimal: true
        units: Units.GJyear
        classes: RESIDENTIAL: {}
      cop_hws:
        label: 'HWS COP'
        desc: 'Coefficient of Performance of the hot water system.'
        type: Number
        decimal: true
        classes: RESIDENTIAL: {defaultValue: 1}
      en_cook:
        label: 'Cooktop and Oven'
        desc: 'Energy required for cooking in the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: 'IF($energy_demand.src_cook=="Electricity", $energy.fitout.en_elec_oven, IF($energy_demand.src_cook=="Gas", $energy.fitout.en_gas_oven)) * ($space.num_0br + $space.num_1br + $space.num_2br + $space.num_3plus)'
        classes: RESIDENTIAL: {}
    # TODO(aramk) Default value should be based on src_cook.
      src_cook:
        label: 'Cooktop and Oven Source'
        desc: 'Energy source in the typology used for cooking. Used to calculate CO2-e.'
        type: String
        allowedValues: _.without(EnergySources, EnergySources.COGEN)
        classes: RESIDENTIAL: {defaultValue: ENERGY_SOURCE_ELEC}
      en_elec:
        label: 'Operating Electricity'
        desc: 'Operating electricity demand'
        units: Units.MJyear
        type: Number
        decimal: true
        calc: ->
          value = 0
          _.each {
            'src_heat': 'en_heat'
            'src_cool': 'en_cool'
            'src_cook': 'en_cook'
          }, (energyParamId, sourceParamId) =>
            if @param('energy_demand.' + sourceParamId) == ENERGY_SOURCE_ELEC
              value += @param('energy_demand.' + energyParamId)
          if @param('energy_demand.src_hwat') == ENERGY_SOURCE_ELEC
            value += @param('energy_demand.en_hwat') * 1000
          value += @KWH_TO_MJ(@param('energy_demand.en_light'))
          value += @param('energy_demand.en_app') - @KWH_TO_MJ(@param('energy_demand.en_pv'))
          value
      en_gas:
        label: 'Operating Gas'
        desc: 'Operating gas demand'
        units: Units.MJyear
        type: Number
        decimal: true
        calc: ->
          value = 0
          if @param('energy_demand.src_heat') == ENERGY_SOURCE_GAS
            value += @param('energy_demand.en_heat')
          if @param('energy_demand.src_hwat') == ENERGY_SOURCE_GAS
            value += @param('energy_demand.en_hwat') * 1000
          if @param('energy_demand.src_cook') == ENERGY_SOURCE_GAS
            value += @param('energy_demand.en_cook')
          value
      prpn_elec_scheme:
        label: 'Proportion Electricity - Scheme vs Cogen'
        desc: 'Proportion of total electricity demand sourced from scheme power, versus scheme plus cogeneration.'
        type: Number
        decimal: true
        classes: RESIDENTIAL: {defaultValue: 1}
      en_elec_scheme:
        label: 'Scheme Electricity'
        desc: 'Electricity demand supplied by scheme power.'
        units: Units.MJyear
        type: Number
        decimal: true 
        calc: ->
          en_elec = @param('energy_demand.en_elec')
          if en_elec < 0
            en_elec
          else
            @param('energy_demand.prpn_elec_scheme') * en_elec
      en_elec_cogen:
        label: 'Cogen Electricity'
        desc: 'Electricity demand supplied by scheme power.'
        units: Units.MJyear
        type: Number
        decimal: true 
        calc: 'MAX(((1 - $energy_demand.prpn_elec_scheme) * $energy_demand.en_elec), 0)'
      en_cogen:
        label: 'Cogen Total'
        desc: 'Total cogen energy used by the typology.'
        units: Units.MJyear
        type: Number
        decimal: true 
        calc: ->
          value = @param('energy_demand.en_elec_cogen') ? 0
          if @param('energy_demand.src_heat') == ENERGY_SOURCE_COGEN
            value += @param('energy_demand.en_heat')
          if @param('energy_demand.src_cool') == ENERGY_SOURCE_COGEN
            value += @param('energy_demand.en_cool')
          if @param('energy_demand.src_hwat') == ENERGY_SOURCE_COGEN
            value += @param('energy_demand.en_hwat')
          value
      en_app:
        label: 'Appliances'
        desc: 'Energy required for powering appliances in the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: ->
          type_app = @param('energy_demand.type_app')
          unless type_app then return
          type_en = @param('energy.fitout.' + ApplianceTypes[type_app])
          rooms = @calc('$space.num_0br + $space.num_1br + $space.num_2br + $space.num_3plus')
          type_en * rooms
      type_app:
        label: 'Appliances Source'
        desc: 'Type of appliance fit out.'
        type: String
        allowedValues: Object.keys(ApplianceTypes),
        classes: RESIDENTIAL: {defaultValue: 'Basic - Avg Performance'}
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
      en_int_e_r:
        label: 'Residential Energy Intensity - Electricity'
        desc: 'Residential electricity energy use intensity of the typology.'
        type: Number
        decimal: true
        units: Units.MJm2year
        classes: MIXED_USE: {defaultValue: 535}
      en_int_e_c:
        label: 'Commercial Energy Intensity - Electricity'
        desc: 'Commercial electricity energy use intensity of the typology.'
        type: Number
        decimal: true
        units: Units.MJm2year
        classes: MIXED_USE: {defaultValue: 1140}
      en_use_e:
        desc: 'Electricity energy use of the typology.'
        label: 'Energy Use - Electricity'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: ->
          typologyClass = Entities.getTypologyClass(@model)
          if typologyClass == 'MIXED_USE'
            @calc('$energy_demand.en_int_e_r * $space.gfa_r + $energy_demand.en_int_e_c * $space.gfa_c')
          else
            @calc('$energy_demand.en_int_e * $space.gfa_t')
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
      en_int_g_r:
        label: 'Residential Energy Intensity - Gas'
        desc: 'Residential gas energy use intensity of the typology.'
        type: Number
        decimal: true
        units: Units.MJm2year
        classes: MIXED_USE: {defaultValue: 455}
      en_int_g_c:
        label: 'Commercial Energy Intensity - Gas'
        desc: 'Commercial gas energy use intensity of the typology.'
        type: Number
        decimal: true
        units: Units.MJm2year
        classes: MIXED_USE: {defaultValue: 465}
      # en_int_g_t:
      #   desc: 'Gas energy use intensity of the typology.'
      #   label: 'Energy Use Intensity - Gas'
      #   type: Number
      #   decimal: true
      #   units: Units.MJm2year
      #   calc: ->
      #     typologyClass = Entities.getTypologyClass(@model)
      #     if typologyClass == 'MIXED_USE'
      #       @param('space.en_int_g_r') + @param('space.en_int_g_c')
      #     else
      #       @param('space.en_int_g')
      en_use_g:
        desc: 'Gas energy use of the typology.'
        label: 'Energy Use - Gas'
        type: Number
        decimal: true
        units: Units.MJyear
        # calc: '$energy_demand.en_int_g_t * $space.gfa_t'
        calc: ->
          typologyClass = Entities.getTypologyClass(@model)
          if typologyClass == 'MIXED_USE'
            @calc('$energy_demand.en_int_g_r * $space.gfa_r + $energy_demand.en_int_g_c * $space.gfa_c')
          else
            @calc('$energy_demand.en_int_g * $space.gfa_t')
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
          if isNonResidentialBuildingClass(Entities.getTypologyClass(@model))
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
        decimal: true
        units: Units.kgco2
        calc: '($space.ext_land_l + $space.ext_land_a + $space.ext_land_h) * $embodied_carbon.landscaping.greenspace'
      e_co2_imp:
        label: 'Impervious'
        desc: 'CO2 embodied in the impervious portion of external land.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$space.ext_land_i * $embodied_carbon.landscaping.impermeable'
      e_co2_emb:
        label: 'Total External Embodied'
        desc: 'CO2 embodied in the external impermeable surfaces.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$embodied_carbon.e_co2_green + $embodied_carbon.e_co2_imp'
      i_co2_emb_intensity:
        label: 'CO2 - Internal Embodied Intensity'
        desc: 'CO2 per square metre embodied in the building.'
        type: Number
        decimal: true
        units: Units.kgco2m2
        classes:
          RESIDENTIAL: {defaultValue: 180}
          COMMERCIAL:
            subclasses:
              'Retail': {defaultValue: 375}
              'Office': {defaultValue: 450}
              'Hotel': {defaultValue: 480}
              'Supermarket': {defaultValue: 375}
              'Restaurant': {defaultValue: 350}
          MIXED_USE: {defaultValue: 480}
          INSTITUTIONAL:
            subclasses:
              'School': {defaultValue: 475}
              'Tertiary': {defaultValue: 475}
              'Hospital': {defaultValue: 380}
              'Public': {defaultValue: 375}
      i_co2_emb_intensity_value:
        label: 'Internal Embodied'
        desc: 'CO2 embodied in the materials of the typology calculated using the intensity and GFA.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$embodied_carbon.i_co2_emb_intensity * $space.gfa_t'
      t_co2_emb:
        label: 'Total Embodied'
        desc: 'Total CO2 embodied in the property.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$embodied_carbon.e_co2_emb + $embodied_carbon.i_co2_emb_intensity_value + $parking.co2_ug_tot'
      t_co2_emb_asset:
        label: 'Total Embodied'
        desc: 'Total CO2 embodied in the asset.'
        type: Number
        decimal: true
        units: Units.kgco2year
        classes: ASSET: {}
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
        units: Units.kgco2year
        calc: -> calcEnergyC02.call(@, 'energy_demand.src_heat', 'energy_demand.en_heat' , 'co2_int_heat')
      co2_cool:
        label: 'Cooling'
        desc: 'CO2 emissions due to cooling the typology.'
        type: Number
        decimal: true
        units: Units.kgco2year
        calc: -> calcEnergyC02.call(@, 'energy_demand.src_cool', 'energy_demand.en_cool', 'co2_int_cool')
      co2_light:
        label: 'Lighting'
        desc: 'CO2-e emissions due to lighting the typology.'
        type: Number
        decimal: true
        units: Units.kgco2year
        calc: '$energy_demand.en_light * ($operating_carbon.elec * $energy_demand.prpn_elec_scheme) + KWH_TO_MJ($energy_demand.en_light) * $energy.cogen.operating_carbon.co2_int_elec * (1 - $energy_demand.prpn_elec_scheme)'
      co2_hwat:
        label: 'Hot Water'
        desc: 'CO2-e emissions due to hot water heating in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2year
        calc: ->
          co2 = calcEnergyC02.call(@, 'energy_demand.src_hwat', 'energy_demand.en_hwat', 'co2_int_heat')
          if co2? then co2 * 1000 else null
      co2_cook:
        label: 'Cooktop and Oven'
        desc: 'CO2-e emissions due to cooking in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2year
        calc: -> calcEnergyC02.call(@, 'energy_demand.src_cook', 'energy_demand.en_cook', 'co2_int_heat')
      co2_app:
        label: 'Appliances'
        desc: 'CO2-e emissions due to powering appliances in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2year
        calc: '$energy_demand.en_app * $operating_carbon.elec_mj * $energy_demand.prpn_elec_scheme + $energy_demand.en_app * $energy.cogen.operating_carbon.co2_int_elec * (1 - $energy_demand.prpn_elec_scheme)'
      co2_trans:
        label: 'Transport'
        desc: 'CO2-e emissions due to transport.'
        type: Number
        decimal: true
        units: Units.kgco2year
      # TODO(aramk) Add once we have pathways.
        calc: '0'
      co2_op_tot:
        label: 'Total Operating'
        desc: 'Total operating CO2 from all energy uses.'
        type: Number
        decimal: true
        units: Units.kgco2year
        classes: BuildingClasses
        calc: ->
          if isNonResidentialBuildingClass(Entities.getTypologyClass(@model))
            @calc('$operating_carbon.co2_op_e + $operating_carbon.co2_op_g')
          else
            @calc('$operating_carbon.co2_heat + $operating_carbon.co2_cool + $operating_carbon.co2_light + $operating_carbon.co2_hwat + $operating_carbon.co2_cook + $operating_carbon.co2_app - ($energy_demand.en_pv * $operating_carbon.elec)')
      co2_op_e:
        desc: 'Operating CO2 from electricity use.'
        label: 'CO2 - Electricity'
        type: Number
        units: Units.kgco2year
        calc: '(MJ_TO_KWH($energy_demand.en_use_e) - $energy_demand.en_pv) * $operating_carbon.elec'
      co2_op_g:
        desc: 'Operating CO2 from gas use.'
        label: 'CO2 - Gas'
        type: Number
        units: Units.kgco2year
        calc: 'MJ_TO_KWH($energy_demand.en_use_g) * $operating_carbon.elec'
  cogen:
    label: 'Cogen/Trigen'
    classes: RESIDENTIAL: {}
    items:
      demand:
        items:
          elec:
            label: 'Electricity'
            desc: 'Electricity energy demand.'
            type: Number
            decimal: true
            units: Units.MJyear
            calc: '$energy_demand.en_elec_cogen'
          heat:
            label: 'Heating'
            desc: 'Space heating energy demand.'
            type: Number
            decimal: true
            units: Units.MJyear
            calc: ->
              if @param('energy_demand.src_heat') == ENERGY_SOURCE_COGEN
                @param('energy_demand.therm_en_heat')
          cool:
            label: 'Cooling'
            desc: 'Space cooling energy demand.'
            type: Number
            decimal: true
            units: Units.MJyear
            calc: ->
              if @param('energy_demand.src_cool') == ENERGY_SOURCE_COGEN
                @param('energy_demand.therm_en_cool')
          hwat:
            label: 'Hot Water'
            desc: 'Hot water heating energy demand.'
            type: Number
            decimal: true
            units: Units.MJyear
            calc: ->
              if @param('energy_demand.src_hwat') == ENERGY_SOURCE_COGEN
                @param('energy_demand.therm_en_hwat') * 1000
          therm:
            label: 'Total Thermal'
            desc: 'Total thermal energy demand.'
            type: Number
            decimal: true
            units: Units.MJ
            calc: '$cogen.demand.heat + $cogen.demand.cool + $cogen.demand.hwat'
          total:
            label: 'Total'
            desc: 'Total demand for cogen/trigen energy.'
            type: Number
            decimal: true
            units: Units.MJ
            calc: '$cogen.demand.elec + $cogen.demand.therm'
      balance:
        label: 'Balance of Supply'
        items:
          excess_elec:
            desc: 'Balance of electricity remaining after precinct object use.'
            label: 'Excess Electricity'
            type: Number
            units: Units.MJyear
            calc: '$energy.cogen.output.elec_output - $cogen.demand.elec'
          excess_heat:
            desc: 'Balance of heating energy remaining after precinct object use.'
            label: 'Excess Heating Energy'
            type: Number
            units: Units.MJyear
            calc: '$energy.cogen.output.th_en_heat - $cogen.demand.heat - $cogen.demand.hwat'
          excess_cool:
            desc: 'Balance of cooling energy remaining after precinct object use.'
            label: 'Excess Cooling Energy'
            type: Number
            units: Units.MJyear
            calc: '$energy.cogen.output.th_en_cool - $cogen.demand.cool'
  water_demand:
    label: 'Water Demand'
    items:
      # NOTE: This is used for residential, whereas i_wu_intensity_m2 is used for other classes. Note
      # that the units vary.
      i_wu_intensity_occ:
        label: 'Internal Water Use Intensity'
        desc: 'Internal water use per occupant of the typology.'
        type: Number
        decimal: true
        units: Units.kLOccupantYear
        classes: RESIDENTIAL: {}
      i_wu_intensity_rain:
        label: 'Internal Water Use Intensity - Rain'
        type: Number
        decimal: true
        units: Units.kLOccupantYear
        classes: RESIDENTIAL: {}
      i_wu_intensity_treat:
        label: 'Internal Water Use Intensity - Treated'
        type: Number
        decimal: true
        units: Units.kLOccupantYear
        classes: RESIDENTIAL: {}
      i_wu_intensity_grey:
        label: 'Internal Water Use Intensity - Grey'
        type: Number
        decimal: true
        units: Units.kLOccupantYear
        classes: RESIDENTIAL: {}
      i_wu_pot:
        label: 'Internal Water Use - Potable'
        desc: 'Internal potable water use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: -> Math.max(@calc('$water_demand.i_wu_total - $water_demand.i_wu_rain'), 0)
        classes: RESIDENTIAL: {}
      i_wu_rain:
        label: 'Internal Water Use - Rainwater'
        desc: 'Internal rainwater use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: '$water_demand.rain_supply * $water_demand.i_share_rain'
        classes: RESIDENTIAL: {}
      i_wu_intensity_m2:
        label: 'Internal Water Use Intensity'
        desc: 'Internal potable water use intensity of the typology.'
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
      i_wu_intensity_r:
        label: 'Internal Water Use Intensity - Residential'
        desc: 'Residential internal potable water use intensity of the typology.'
        type: Number
        decimal: true
        units: Units.kLm2year
        classes: MIXED_USE: {defaultValue: 2.70}
      i_wu_intensity_c:
        label: 'Internal Water Use Intensity - Commercial'
        desc: 'Commercial internal potable water use intensity of the typology.'
        type: Number
        decimal: true
        units: Units.kLm2year
        classes: MIXED_USE: {defaultValue: 1.70}
      rain_sys:
        label: 'Rainwater System'
        desc: 'Whether the typology includes a rainwater capture system.'
        type: Boolean
        classes: extendClassesWithDefault(extendBuildingClasses(), false)
      grey_sys:
        label: 'Greywater System'
        desc: 'Whether the typology includes a greywater system.'
        type: Boolean
        classes: extendClassesWithDefault(extendBuildingClasses(), false)
      rain_supply:
        label: 'Rainwater System Supply'
        desc: 'Total rainwater supply generated by the rainwater system, if one exists.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: ->
          if @param('water_demand.rain_sys')
            @calc('$space.fpa * $external_water.avg_annual_rainfall / 1000 * $external_water.rain_sys_eff')
          else
            0
      i_share_rain:
        label: 'Share of Rainwater Use - Internal vs External'
        desc: 'Share of the total rainwater supply used internally in the typology.'
        type: Number
        decimal: true
        classes: extendClassesWithDefault(extendBuildingClasses(), 0.5)
      share_i_wu_to_grey:
        label: 'Share of Internal Water Use to Greywater'
        desc: 'Share of the total internal water use waste diverted to greywater.'
        type: Number
        decimal: true
        classes: extendClassesWithDefault(extendBuildingClasses(), 0.75)
      share_e_wu_pot:
        label: 'External Share of Balance - Bore vs Potable'
        desc: 'Share of balance water demand to be supplied by bore water versus potable water.'
        type: Number
        decimal: true
        classes: extendClassesWithDefault(extendBuildingClasses(OPEN_SPACE: {}), 0)
      i_wu_total:
        label: 'Internal Water Use - Total'
        desc: 'Total internal water use of the typology.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: ->
          if isNonResidentialBuildingClass(Entities.getTypologyClass(@model))
            typologyClass = Entities.getTypologyClass(@model)
            if typologyClass == 'MIXED_USE'
              @calc('$water_demand.i_wu_intensity_r * $space.gfa_r + $water_demand.i_wu_intensity_c * $space.gfa_c')
            else
              @calc('$water_demand.i_wu_intensity_m2 * $space.gfa_t')
          else
            @calc('$water_demand.i_wu_intensity_occ * $space.occupants')
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
      e_wu_pot:
        label: 'External Water Use - Potable'
        type: Number
        decimal: true
        desc: 'External potable water use.'
        units: Units.kLyear
        calc: '$water_demand.e_wd_total - $water_demand.e_wu_bore - $water_demand.e_wu_rain - $water_demand.e_wu_grey'
      e_wu_bore:
        label: 'External Water Use - Bore'
        type: Number
        decimal: true
        desc: 'External bore water use.'
        units: Units.kLyear
        calc: ->
          value = @calc('($water_demand.e_wd_total - $water_demand.e_wu_rain - $water_demand.e_wu_grey) * $water_demand.share_e_wu_pot')
          Math.max(value, 0)
      e_wu_grey:
        label: 'External Water Use - Greywater'
        type: Number
        decimal: true
        desc: 'External greywater use.'
        units: Units.kLyear
        calc: ->
          if @param('water_demand.grey_sys')
            @calc('$water_demand.share_i_wu_to_grey * $water_demand.i_wu_total')
          else
            0
      e_wu_rain:
        label: 'External Water Use - Rainwater'
        type: Number
        decimal: true
        desc: 'External rainwater use.'
        units: Units.kLyear
        calc: '(1 - $water_demand.i_share_rain) * $water_demand.rain_supply'
      wu_pot_tot:
        label: 'Total Potable Water Use'
        desc: 'Total potable water use for internal and external purposes.'
        type: Number
        decimal: true
        units: Units.kLyear
        calc: ->
          typologyClass = Entities.getTypologyClass(@model)
          if isNonResidentialBuildingClass(typologyClass)
            i_wu_pot = @param('water_demand.i_wu_total')
          else if typologyClass == 'OPEN_SPACE'
            # Open space has no internal water usage component.
            i_wu_pot = 0
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
          MIXED_USE:
            defaultValue: 'Custom'
            allowedValues: Object.keys(MixedUseBuildTypes)
            getCostParamId: (args) -> 'financial.mixed_use.' + MixedUseBuildTypes[args.value]
          INSTITUTIONAL: createBuildTypeClassOptions(InstitutionalBuildTypes, 'institutional')
      cost_land:
        label: 'Cost - Land Parcel'
        type: Number
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
        classes: extendBuildingClasses()
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
        units: Units.$
        classes: BuildingClasses
        calc: ->
          if isNonResidentialBuildingClass(Entities.getTypologyClass(@model))
            calcEnergyWithIntensityCost.call(@, 'elec', 'e')
          else
            calcElecCost.call(@)
      cost_op_g:
        label: 'Cost - Gas Usage'
        desc: 'Operating costs due to gas usage.'
        type: Number
        units: Units.$
        classes: BuildingClasses
        calc: ->
          if isNonResidentialBuildingClass(Entities.getTypologyClass(@model))
            calcEnergyWithIntensityCost.call(@, 'gas', 'g')
          else
            calcEnergyCost2.call(@, 'gas')
      cost_op_w:
        label: 'Cost - Water Usage'
        desc: 'Operating costs due to water usage.'
        type: Number
        units: Units.$
        calc: '$utilities.price_supply_water + $water_demand.wu_pot_tot * $utilities.price_usage_water'
      cost_op_cogen:
        label: 'Cost – Cogen Usage'
        desc: 'Operating costs due to cogen usage.'
        type: Number
        units: Units.$
        classes: RESIDENTIAL: {}
        calc: ->
          calcEnergyCost2.call(@, 'cogen')
      cost_op_w:
        label: 'Cost - Water Usage'
        desc: 'Operating costs due to water usage.'
        type: Number
        units: Units.$
        calc: '$utilities.price_supply_water + $water_demand.wu_pot_tot * $utilities.price_usage_water'
      cost_op_t:
        label: 'Cost - Total Operating'
        desc: 'Total operating cost of the typology including electricity and gas usage.'
        type: Number
        units: Units.$
        calc: '$financial.cost_op_e + $financial.cost_op_g + $financial.cost_op_w'
      cost_asset:
        label: 'Cost - Total'
        desc: 'Total cost of the asset.'
        type: Number
        units: Units.$
        classes: ASSET: {}
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
        units: Units.deg
        classes: extendClassesWithDefault(extendLandClasses(), 0)
      eq_azmth_h:
        label: 'Azimuth Heating Energy Array'
        desc: 'Equation to predict heating energy use as a function of degrees azimuth.'
        type: String
        classes: RESIDENTIAL: {}
      eq_azmth_c:
        label: 'Azimuth Cooling Energy Array'
        desc: 'Equation to predict cooling energy use as a function of degrees azimuth.'
        type: String
        classes: RESIDENTIAL: {}
  parking:
    label: 'Parking'
    items:
      parking_ga:
        label: 'Parking Spaces - Garage'
        desc: 'Number of garage parking spaces.'
        type: Number
        units: Units.spaces
        classes: RESIDENTIAL: {defaultValue: 0}
      parking_ug:
        label: 'Parking Spaces - Underground'
        desc: 'Number of underground parking spaces.'
        type: Number
        units: Units.spaces
        defaultValue: 0
        classes: extendBuildingClasses()
      parking_sl:
        label: 'Parking Spaces - Street Level'
        desc: 'Number of street level parking spaces.'
        type: Number
        units: Units.spaces
        calc: ->
          prk_area_veh = @param('parking.prk_area_veh')
          if prk_area_veh == 0 then return 0
          @calc('$space.ext_land_i * $parking.parking_land') / prk_area_veh
        classes: extendBuildingClasses
          PATHWAY: {}
      parking_t:
        label: 'Parking Spaces - Total'
        desc: 'Total number of parking spaces.'
        type: Number
        units: Units.spaces
        calc: '$parking.parking_ga + $parking.parking_sl + $parking.parking_ug'
        classes: extendBuildingClasses
          PATHWAY: {}
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
      co2_ug_tot:
        label: 'Underground Parking'
        type: Number
        units: Units.kgco2
        calc: '$parking.co2_ug * $parking.parking_ug'
  composition:
    label: 'Composition'
    items:
      rd_lanes:
        desc: 'Number of road lanes for vehicular movement.'
        label: 'No. Road Lanes'
        type: Number
        units: Units.lanes
        classes: PATHWAY: {defaultValue: 0}
      rd_width:
        desc: 'Width of the road for vehicular movement.'
        label: 'Road Width'
        type: Number
        decimal: true
        units: Units.m
        classes: PATHWAY: {defaultValue: 3.5}
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
        classes: PATHWAY: {defaultValue: 'Full Depth Asphalt'}
      prk_lanes:
        desc: 'Number of lanes for vehicle parking.'
        label: 'No. Parking Lanes'
        type: Number
        units: Units.lanes
        classes: PATHWAY: {defaultValue: 0}
      prk_width:
        desc: 'Width of the drawn pathway for vehicle parking.'
        label: 'Parking Width'
        type: Number
        decimal: true
        units: Units.m
        classes: PATHWAY: {defaultValue: 3}
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
        classes: PATHWAY: {defaultValue: 'Full Depth Asphalt'}
      fp_lanes:
        desc: 'Number of footpath lanes for pedestrian movement.'
        label: 'No. Footpath Lanes'
        type: Number
        units: Units.lanes
        classes: PATHWAY: {defaultValue: 0}
      fp_width:
        desc: 'Width of a footpath for pedestrian movement.'
        label: 'Footpath Width'
        type: Number
        decimal: true
        units: Units.m
        classes: PATHWAY: {defaultValue: 2}
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
        classes: PATHWAY: {defaultValue: 'Concrete'}
      bp_lanes:
        desc: 'Number of bicycle path lanes for cyclist movement.'
        label: 'No. Bicycle Path Lanes'
        type: Number
        units: Units.lanes
        classes: PATHWAY: {defaultValue: 0}
      bp_width:
        desc: 'Width of a bicycle path lane for cyclist movement.'
        label: 'Bicycle Path Width'
        type: Number
        decimal: true
        units: Units.m
        classes: PATHWAY: {defaultValue: 2}
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
        classes: PATHWAY: {defaultValue: 'Asphalt'}
      ve_lanes:
        desc: 'Number of verge strips as a buffer for the pathway.'
        label: 'No. Verge Strips'
        type: Number
        units: Units.lanes
        classes: PATHWAY: {defaultValue: 2}
      ve_width:
        desc: 'Width of verge as a buffer for the pathway.'
        label: 'Verge Width'
        type: Number
        decimal: true
        units: Units.m
        classes: PATHWAY: {defaultValue: 2}
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
        label: 'VKT per Household'
        desc: 'Vehicle kilometres travelled per household per day.'
        type: Number
        decimal: true
        units: Units.kmday
        calc: ->
          params = TransportModelParameters
          value = calcTransportLinearRegression.call(@, params)
          Math.pow(value, 2)
      vkt_person_day:
        label: 'VKT per Resident'
        desc: 'Vehicle kilometres travelled per resident per day.'
        type: Number
        decimal: true
        units: Units.kmday
        calc: '$transport.vkt_household_day / $transport.hhsize'
      vkt_dwellings_day:
        label: 'VKT total Dwellings'
        desc: 'Vehicle kilometres travelled for all dwellings per day.'
        type: Number
        decimal: true
        units: Units.kmday
        calc: '$transport.vkt_household_day * $space.dwell_tot'
      vkt_household_year:
        label: 'VKT per Household'
        desc: 'Vehicle kilometres travelled per household per year.'
        type: Number
        decimal: true
        units: Units.kmyear
        calc: '$transport.vkt_household_day * 365'
      vkt_person_year:
        label: 'VKT per Resident'
        desc: 'Vehicle kilometres travelled per resident per year.'
        type: Number
        decimal: true
        units: Units.kmyear
        calc: '$transport.vkt_person_day * 365'
      vkt_dwellings_year:
        label: 'VKT total Dwellings'
        desc: 'Vehicle kilometres travelled for all dwellings per year.'
        type: Number
        decimal: true
        units: Units.kmyear
        calc: '$transport.vkt_dwellings_day * 365'
      ghg_household_day:
        label: 'GHG per Household'
        desc: 'Greenhouse gas emissions per household per day.'
        type: Number
        decimal: true
        units: Units.kgco2day
        calc: '$transport.vkt_household_day * $operating_carbon.vkt'
      ghg_person_day:
        label: 'GHG per Resident'
        desc: 'Greenhouse gas emissions per resident per day.'
        type: Number
        decimal: true
        units: Units.kgco2day
        calc: '$transport.vkt_person_day * $operating_carbon.vkt'
      ghg_household_year:
        label: 'GHG per Household'
        desc: 'Greenhouse gas emissions per household per year.'
        type: Number
        decimal: true
        units: Units.kgco2year
        calc: '$transport.ghg_household_day * 365'
      ghg_dwellings_day:
        label: 'GHG total Dwellings'
        desc: 'Greenhouse gas emissions for all dwellings per day.'
        type: Number
        decimal: true
        units: Units.kgco2day
        calc: '$transport.ghg_household_day * $space.dwell_tot'
      ghg_dwellings_year:
        label: 'GHG per Household'
        desc: 'Greenhouse gas emissions per household per year.'
        type: Number
        decimal: true
        units: Units.kgco2year
        calc: '$transport.ghg_dwellings_day * 365'
      ghg_person_year:
        label: 'GHG per Resident'
        desc: 'Greenhouse gas emissions per resident per year.'
        type: Number
        decimal: true
        units: Units.kgco2year
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
        decimal: true
        units: Units.tripsday
        calc: '$transport.trips'
      trips_car_driver:
        label: 'Car as Driver Trips'
        type: Number
        decimal: true
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
        decimal: true
        units: Units.tripsday
        calc: '$transport.total_trips * $transport.mode_share_transit'
      trips_car_active:
        label: 'Active Trips'
        type: Number
        decimal: true
        units: Units.tripsday
        calc: '$transport.total_trips * $transport.mode_share_active'
      total_trips_year:
        label: 'Total Trips'
        type: Number
        decimal: true
        units: Units.tripsyear
        calc: '$transport.total_trips * 365'
      trips_car_driver_year:
        label: 'Car as Driver Trips'
        type: Number
        decimal: true
        units: Units.tripsyear
        calc: '$transport.trips_car_driver * 365'
      trips_car_passenger_year:
        label: 'Car as Passenger Trips'
        type: Number
        decimal: true
        units: Units.tripsyear
        calc: '$transport.trips_car_passenger * 365'
      trips_car_transit_year:
        label: 'Transit Trips'
        type: Number
        decimal: true
        units: Units.tripsyear
        calc: '$transport.trips_car_transit * 365'
      trips_car_active_year:
        label: 'Active Trips'
        type: Number
        decimal: true
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
  desc: extendSchema descSchema,
    desc: 'A detailed description of the typology, including a summary of the materials and services provided.'
  parameters:
    label: 'Parameters'
    type: ParametersSchema
    defaultValue: {}
  project: projectSchema

@Typologies = new Meteor.Collection 'typologies'
Typologies.attachSchema(TypologySchema)
Typologies.ParametersSchema = ParametersSchema
Typologies.Classes = TypologyClasses
Typologies.LandClasses = LandClasses
Typologies.EnergySources = EnergySources
AccountsUtil.setUpProjectAllow(Typologies)

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
  _.map Typologies.Classes, (cls, id) -> Setter.merge(Setter.clone(cls), {_id: id})

Typologies.getSubclassItems = _.memoize (typologyClass) ->
  field = Collections.getField(Typologies, 'parameters.general.subclass')
  options = field?.classes[typologyClass]
  allowedValues = options?.allowedValues ? []
  _.map allowedValues, (value) -> {_id: value, name: value}

Typologies.getAllocatableClassItems = ->
  items = []
  _.each Typologies.Classes, (cls, id) ->
    unless cls.canAllocateToLot == false
      items.push(Setter.merge(Setter.clone(cls), {_id: id}))
  items

# Typologies.getSubclassColors = _.memoize (typologyClass) ->
#   classArgs = TypologyClasses[typologyClass]
#   subclasses = classArgs?.subclasses
#   unless subclasses?
#     return {}
#   colorMap = {}
#   _.each subclasses, (subclassName, i) -> colorMap[subclassName]
#   colorMap

Typologies.getBuildTypeItems = (typologyClass, subclass) ->
  field = Collections.getField(Typologies, 'parameters.financial.build_type')
  options = field?.classes[typologyClass]
  allowedValues = options?.allowedValues ? []
  if Types.isFunction(allowedValues)
    allowedValues = allowedValues(typologyClass: typologyClass, subclass: subclass)
  _.map allowedValues, (value) -> {_id: value, name: value}

Typologies.getRailTypeItems = -> _.map VktRailTypes, (item, id) -> {_id: id, name: item.label}

Typologies.getDefaultParameterValues = ->
  if Types.isString(arguments[0])
    [typologyClass, subclass] = arguments
  else
    typology = arguments[0]
    return {} unless typology
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
      return if classOptions == false
      classDefaultValue = classOptions?.defaultValue
      subclassDefaultValue = classOptions?.subclasses?[subclass]?.defaultValue
      allClassDefaultValue = classes?.ALL?.defaultValue
      defaultValue = subclassDefaultValue ? classDefaultValue ? allClassDefaultValue
      if defaultValue?
        values[paramId] = defaultValue
    SchemaUtils.unflattenParameters(values, false)
  (args) -> JSON.stringify(args)
)

# Get the parameters which have default values for other classes and should be excluded from models
# of the class.
Typologies.getExcludedDefaultParameters = _.memoize (typologyClass) ->
  excluded = {}
  SchemaUtils.forEachFieldSchema ParametersSchema, (fieldSchema, paramId) ->
    classes = fieldSchema.classes
    # Exclude the field unless it's permitted explicitly or if all classes are permitted.
    if Typologies.excludesClassOptions(fieldSchema, typologyClass)
      excluded[paramId] = true
  SchemaUtils.unflattenParameters(excluded, false)

Typologies.mergeDefaults = (model) ->
  defaults = Typologies.getDefaultParameterValues(model)
  mergeDefaultParameters(model, defaults)

mergeDefaultParameters = (model, defaults) ->
  model.parameters ?= {}
  Setter.defaults(model.parameters, defaults)
  model

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

Typologies.getClassMap = (typologies) ->
  unless typologies
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

Typologies.excludesClassOptions = (schema, typologyClass) ->
  classOptions = schema.classes
  typologyClass? && classOptions? && !classOptions[typologyClass] && !classOptions.ALL

####################################################################################################
# LOT SCHEMA DEFINITION
####################################################################################################

lotCategories =
  general:
    items:
    # If provided, this restricts the class of the entity.
      class: extendSchema classSchema, {optional: true}
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
        optional: false
      height: extendSchema heightSchema,
        label: 'Allowable Height'
        desc: 'The maximum allowable height for structures in this lot.'
      area: areaSchema

@LotParametersSchema = createCategoriesSchema
  categories: lotCategories

LotSchema = new SimpleSchema
  name:
    label: 'Name'
    type: String
    desc: 'The full name of the lot.'
  desc: extendSchema descSchema,
    optional: true
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
AccountsUtil.setUpProjectAllow(Lots)

Lots.findByProject = (projectId) -> SchemaUtils.findByProject(Lots, projectId)
Lots.findByEntity = (entityId) -> Lots.findOne({entity: entityId})
Lots.findByTypology = (typologyId) ->
  lots = []
  _.each Entities.find(typology: typologyId).fetch(), (entity) ->
    lot = Lots.findByEntity(entity._id)
    lots.push(lot) if lot
  lots
Lots.findForDevelopment = (projectId) ->
  _.filter Lots.findByProject(projectId).fetch(), (lot) ->
    SchemaUtils.getParameterValue(lot, 'general.develop')
Lots.findNotForDevelopment = (projectId) ->
  _.filter Lots.findByProject(projectId).fetch(), (lot) ->
    !SchemaUtils.getParameterValue(lot, 'general.develop')
Lots.findAvailable = (projectId) ->
  _.filter Lots.findForDevelopment(projectId), (lot) -> !lot.entity
Lots.findWithMissingEntities = ->
  selector = {entity: {$exists: true, $ne: null}}
  options = {fields: {_id: true, entity: true}}
  lots = Lots.find(selector, options).fetch()
  withMissingIds = []
  _.each lots, (lot) -> unless Entities.findOne(lot.entity) then withMissingIds.push(lot._id)
  withMissingIds

Lots.createEntity = (args) ->
  args = _.extend({allowReplace: false, allowNonDevelopment: false}, args)
  lotId = args.lotId
  typologyId = args.typologyId
  allowReplace = args.allowReplace
  lot = Lots.findOne(lotId)
  typology = Typologies.findOne(typologyId)
  if !lot
    return Q.reject('No Lot with ID ' + id)
  else if !typology
    return Q.reject('No Typology with ID ' + typologyId)
  oldEntityId = lot.entity
  oldTypologyId = oldEntityId && Entities.findOne(oldEntityId).typology
  newTypologyId = typology._id
  if oldEntityId && !allowReplace
    return Q.reject('Cannot replace entity on existing Lot with ID ' + lotId)
  else if newTypologyId && oldTypologyId && oldTypologyId == newTypologyId
    # Prevent creating a new entity if the same typology as the existing is specified.
    return Q.resolve(oldEntityId)
  classParamId = 'parameters.general.class'
  developParamId = 'parameters.general.develop'
  lotClass = SchemaUtils.getParameterValue(lot, classParamId)
  isForDevelopment = SchemaUtils.getParameterValue(lot, developParamId)
  # If no class is provided, use the class of the entity's typology.
  unless lotClass
    lotClass = SchemaUtils.getParameterValue(typology, classParamId)
  if args.allowNonDevelopment
    # Ensures the lot will be updated as developable and validation will pass.
    isForDevelopment = true
    SchemaUtils.setParameterValue(lot, developParamId, true)
  df = Q.defer()
  promise = Lots.validateTypology(lot, typologyId)
  promise.fail(df.reject)
  promise.then (result) ->
    if result
      Logger.error('Cannot create Entity on Lot:', result)
      df.reject(result)
      return
    # Create a new entity for this lot-typology combination and remove the existing one
    # (if any). Name of the entity matches that of the lot.
    newEntity =
      name: typology.name
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
          # Remove the newly created entity if the lot could not be updated.
          Entities.remove newEntityId, (removeErr, result) ->
            if removeErr
              df.reject(removeErr)
            else
              df.reject(err)
        else
          # Remove the existing entity (if any) when replacing.
          if allowReplace && oldEntityId
            Entities.remove oldEntityId, (err, result) ->
              if err
                Logger.error('Could not remove old entity with id', oldEntityId, err)
              else
                df.resolve(newEntityId)
          else
            df.resolve(newEntityId)
  df.promise

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
    Logger.error('Lot could not be validated', lot, e, e.stack)

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
  canAllocate = false
  classArgs = Typologies.Classes[typologyClass]
  if classArgs.canAllocateToLot == false
    df.resolve('Typology with class ' + typologyClass + ' cannot be allocated to a Lot.')
  else if typologyId && !isForDevelopment
    df.resolve('Lot is not for development - cannot assign typology.')
  else if !lotClass
    df.resolve('Lot does not have a Typology class assigned.')
  else if typologyClass != lotClass
    df.resolve('Lot does not have same Typology class as the Typology being assigned.')
  else
    # Ensure the geometry of the typology will fit in the lot.
    areaDfs = [GeometryUtils.getModelArea(typology), GeometryUtils.getModelArea(lot)]
    Q.all(areaDfs).then(
      (results) ->
        lotArea = results.pop()
        typologyArea = results.pop()
        if lotArea? && typologyArea? && lotArea <= typologyArea
          df.resolve('Typology must have area less than or equal to the Lot.')
        else
          df.resolve()
      df.reject
    )
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
# extraEntityCategories =
#   space:
#     items:
# Setter.merge(entityCategories, extraEntityCategories)

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
  desc: extendSchema descSchema,
    optional: true
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
Entities.ParametersSchema = EntityParametersSchema
Entities.attachSchema(EntitySchema)
AccountsUtil.setUpProjectAllow(Entities)

Entities.getFlattened = (idOrEntity) ->
  entity = if Types.isString(idOrEntity) then Entities.findOne(idOrEntity) else idOrEntity
  Entities.mergeTypology(entity)
  Typologies.mergeDefaults(entity)
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
  typologies = Typologies.findByClass(typologyClass, projectId).fetch()
  entities = []
  _.each typologies, (typology) ->
    Entities.findByTypology(typology._id).forEach (entity) -> entities.push(entity)
  entities

Entities.getTypologyClass = (idOrModel) ->
  entity = if Types.isObject(idOrModel) then idOrModel else Entities.findOne(idOrModel)
  return unless entity?
  typologyId = entity.typology
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
    {collection: Typologies, observe: ['changed']},
    {collection: Projects, observe: ['changed']}
  ], (args) ->
    collection = args.collection
    shouldRefresh = false
    refreshReport = -> if shouldRefresh then PubSub.publish('report/refresh')
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

# Changes to these fields will trigger the energy demand calculations.
azimuthArrayDependencyFieldIds = ['parameters.space.cfa', 'parameters.orientation.azimuth',
  'parameters.orientation.eq_azmth_h', 'parameters.orientation.eq_azmth_c']

# A queue of entity IDs which should be updated with blank modifiers so their azimuth-based values
# are updated. This must take place after the typology is modified so that it inherits the updated
# values.
entityUpdateQueue = []
updateQueuedEntities = ->
  while entityUpdateQueue.length > 0
    entityId = entityUpdateQueue.pop()
    entity = Entities.findOne(entityId)
    # NOTE: We must update a valid field, otherwise an empty $set will throw an error and remove the
    # fields in the entity doc.
    Entities.update(entityId, {$set: {name: entity.name}}, {validate: false})

# Update the energy demand based on the azimuth array.
updateAzimuthEnergyDemand = (userId, doc, fieldNames, modifier) ->
  isUpdating = modifier?
  depResult = getModifiedDocWithDeps(doc, modifier, azimuthArrayDependencyFieldIds)
  fullDoc = depResult.fullDoc
  isEntity = doc.typology?
  return unless depResult.hasDependencyUpdates || isEntity
  Entities.getFlattened(fullDoc) if isEntity
  eq_azmth_h = SchemaUtils.getParameterValue(fullDoc, 'parameters.orientation.eq_azmth_h')
  eq_azmth_c = SchemaUtils.getParameterValue(fullDoc, 'parameters.orientation.eq_azmth_c')
  azimuth = SchemaUtils.getParameterValue(fullDoc, 'parameters.orientation.azimuth') ? 0
  cfa = SchemaUtils.getParameterValue(fullDoc, 'parameters.space.cfa')
  return unless cfa? && azimuth?
  $set = {}
  items = [
    {array: eq_azmth_h, energyParamId: 'parameters.energy_demand.therm_en_heat'}
    {array: eq_azmth_c, energyParamId: 'parameters.energy_demand.therm_en_cool'}
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
    'parameters.general.subclass', 'parameters.space.gfa', 'parameters.space.gfa_r',
    'parameters.space.gfa_c']

updateBuildType = (userId, doc, fileNames, modifier) ->
  depResult = getModifiedDocWithDeps(doc, modifier, buildTypeDependencyFieldIds)
  fullDoc = depResult.fullDoc
  Typologies.mergeDefaults(fullDoc)
  project = Projects.mergeDefaults(Projects.findOne(fullDoc.project))
  return unless depResult.hasDependencyUpdates
  build_type = SchemaUtils.getParameterValue(fullDoc, 'financial.build_type')
  typologyClass = SchemaUtils.getParameterValue(fullDoc, 'general.class')
  subclass = SchemaUtils.getParameterValue(fullDoc, 'general.subclass')
  gfaParamId = 'space.gfa'
  if typologyClass == 'MIXED_USE'
    # Mixed use has two components for GFA.
    gfaParamId = 'space.gfa_t'
    dummyEntity = {typology: fullDoc._id, parameters: fullDoc.parameters, project: fullDoc.project}
    EntityUtils.evaluate(dummyEntity, gfaParamId)
  gfa = SchemaUtils.getParameterValue(fullDoc, gfaParamId)
  $set = {}
  return unless build_type? && build_type != 'Custom' && gfa?
  field = Collections.getField(Typologies, 'parameters.financial.build_type')
  options = field?.classes[typologyClass]
  costParamId =
    options.getCostParamId(typologyClass: typologyClass, subclass: subclass, value: build_type)
  costParamValue = SchemaUtils.getParameterValue(project, costParamId)
  cost_ug_park = SchemaUtils.getParameterValue(project, 'financial.parking.cost_ug_park')
  parking_ug = SchemaUtils.getParameterValue(fullDoc, 'parking.parking_ug')
  parkingCost = if parking_ug? then cost_ug_park * parking_ug else 0
  $set['parameters.financial.cost_con'] = costParamValue * gfa + parkingCost
  applyModifierSet(doc, modifier, $set)

Typologies.before.insert(updateBuildType)
Typologies.before.update(updateBuildType)

####################################################################################################
# SANITIZATION
####################################################################################################

# Ensure the azimuth value for entities and typologies is in the range [0, 360].

sanitizeAzimuth = (azimuth) ->
  azimuth = azimuth % 360
  if azimuth < 0
    azimuth = 360 + azimuth
  else if azimuth == 0
    # Eliminate possible -0.
    azimuth = 0
  azimuth

azimuthFieldId = 'parameters.orientation.azimuth'

_.each [Entities, Typologies], (collection) ->
  collection.before.update (userId, entity, fieldNames, modifier) ->
    azimuth = modifier.$set?[azimuthFieldId]
    if azimuth?
      modifier.$set[azimuthFieldId] = sanitizeAzimuth(azimuth)
  collection.before.insert (userId, doc) ->
    azimuth = SchemaUtils.getParameterValue(doc, azimuthFieldId)
    if azimuth?
      SchemaUtils.setParameterValue(doc, azimuthFieldId, sanitizeAzimuth(azimuth))

####################################################################################################
# ASSOCIATION MAINTENANCE
####################################################################################################

# Remove the entity from the lot when removing the entity.
Entities.after.remove (userId, entity) ->
  lot = Lots.findByEntity(entity._id)
  Lots.update(lot._id, {$unset: {entity: null}}) if lot?

Lots.after.update (userId, lot, fieldNames, modifier) ->
  # Remove the entity when the lot's entity field is unset.
  if modifier.$unset?.entity != undefined
    Entities.remove(@previous.entity)

Lots.before.update (userId, lot, fieldNames, modifier) ->
  newLot = Collections.simulateModifierUpdate(lot, modifier)
  entityId = newLot.entity
  return unless entityId
  typologyClass = SchemaUtils.getParameterValue(newLot, 'general.class')
  entityTypologyClass = Entities.getTypologyClass(entityId)
  if typologyClass != entityTypologyClass
    delete modifier.$set?.entity
    modifier.$unset ?= {}
    modifier.$unset.entity = null

Lots.after.remove (userId, lot) ->
  # Remove the entity when the lot is removed.
  entityId = lot.entity
  Entities.remove(entityId) if lot.entity?

Typologies.after.remove (userId, typology) ->
  # Remove entities when the typology is removed.
  Entities.findByTypology(typology._id).forEach (entity) -> Entities.remove(entity._id)

####################################################################################################
# LAYERS
####################################################################################################

@LayerDisplayModes =
  extrusion: 'Extrusion'
  nonDevExtrusion: 'Extrude Non-Develop'
layerCategories = Setter.clone(entityCategories)
layerCategories.general.items.displayMode =
  label: 'Display Mode'
  type: String
  allowedValues: Object.keys(LayerDisplayModes)
  optional: true
LayerParametersSchema = createCategoriesSchema
  categories: layerCategories

LayerSchema = new SimpleSchema
  name:
    type: String
    index: true
    unique: false
  desc: extendSchema descSchema,
    optional: true
  parameters:
    label: 'Parameters'
    type: LayerParametersSchema
    # Necessary to allow required fields within.
    optional: false
    defaultValue: {}
  project: projectSchema

@Layers = new Meteor.Collection 'layers'
Layers.attachSchema(LayerSchema)
AccountsUtil.setUpProjectAllow(Layers)
Layers.findByProject = (projectId) -> SchemaUtils.findByProject(Layers, projectId)
Layers.getDisplayModeItems = -> _.map LayerDisplayModes, (value, key) -> {label: value, value: key}

####################################################################################################
# USER ASSETS SCHEMA DEFINITION
####################################################################################################

# UserAssetTypes =
#   tree:
#     name: 'Tree'
#     filename: 'tree_simple.dae'

# userAssetCategories =
#   general:
#     items:
#       type:
#         type: String
#         allowedValues: _.keys(UserAssetTypes)
#   space:
#     items:
#       position:
#         type: PositionSchema
#         optional: false
#       scale:
#         type: VertexSchema
#         optional: true
#       rotation:
#         type: VertexSchema
#         optional: true
#       # TODO(aramk) For some reason, latitude and longitude are required even though offset is
#       # optional. Using this as a workaround.
#       offset:
#         type: PositionSchema
#         optional: true

# UsersAssetParametersSchema = createCategoriesSchema
#   categories: userAssetCategories

# UserAssetsSchema = new SimpleSchema
#   name:
#     type: String
#     index: true
#     unique: false
#   desc: extendSchema descSchema,
#     optional: true
#   parameters:
#     label: 'Parameters'
#     type: UsersAssetParametersSchema
#     # Necessary to allow required fields within.
#     optional: false
#     defaultValue: {}
#   project: projectSchema

# @UserAssets = new Meteor.Collection 'userAssets'
# UserAssets.attachSchema(UserAssets)
# AccountsUtil.setUpProjectAllow(UserAssets)
# UserAssets.findByProject = (projectId) -> SchemaUtils.findByProject(UserAssets, projectId)

####################################################################################################
# COLLECTIONS
####################################################################################################

@CollectionUtils =
  getAll: -> [Projects, Entities, Typologies, Lots, Layers]


