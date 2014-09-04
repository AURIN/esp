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
EnergySources = ['Electricity', 'Gas']
WaterDemandSources = ['Potable', 'Bore', 'Rainwater Tank', 'On-Site Treated', 'Greywater']

# ^ and _ are converted to superscript and subscript in forms and reports.
Units =
  m: 'm'
  mm: 'mm'
  m2: 'm^2'
  $m2: '$/m^2'
  $: '$'
  $day: '$/day'
  $kWh: '$/kWh'
  $MJ: '$/MJ'
  $kL: '$/kL'
  deg: 'degrees'
  kgco2: 'kg CO_2-e'
  kgco2m2: 'kg CO_2-e/m^2'
  kL: 'kL'
  kLm2year: 'kL/m²/year'
  co2kWh: 'CO2-e/kWh'
  Lsec: 'L/second'
  Lyear: 'L/year'
  MLyear: 'ML/year'
  kWhyear: 'kWh/year'
  kWh: 'kWh'
  kWhday: 'kWh/day'
  MJyear: 'MJ/year'
  GJyear: 'GJ/year'

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
  units: Units.m2
  calc: -> calcArea(@model._id)

# NOTE: energyParamId expected to be in MJ.
calcEnergyC02 = (sourceParamId, energyParamId, paramGetter) ->
  src = paramGetter(sourceParamId)
  en = paramGetter(energyParamId)
  return null unless src? and en?
  # Convert kWh to MJ
  if src == 'Electricity'
    en * paramGetter('operating_carbon.elec') / 3.6
  else if src == 'Gas'
    en * paramGetter('operating_carbon.gas') / 3.6

extendSchema = (orig, changes) ->
  _.extend({}, orig, changes)

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
        desc: 'Typology within a class. Ex. "Community Garden", "Park" or "Public Plaza".'
      climate_zn:
        desc: 'BOM climate zone number.'
        label: 'Climate Zone'
        type: Number
      type:
        type: String
        desc: 'Version of the subclass.'
        allowedValues: TypologyTypes
  space:
    label: 'Space'
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
      })
      gfa:
        label: 'Gross Floor Area'
        desc: 'Gross floor area of all the rooms in the typology.'
        type: Number
        decimal: true
        units: Units.m2
      cfa:
        label: 'Conditioned Floor Area'
        desc: 'Total conditioned area of the typology.'
        type: Number
        decimal: true
        units: Units.m2
      storeys:
        label: 'Storeys'
        desc: 'Number of floors/storeys in the typology.'
        type: Number
        units: 'Floors'
      height: heightSchema
      occupants:
        label: 'No. Occupants'
        desc: 'Number of occupants in the typology.'
        type: Number
        units: 'Persons'
      num_0br:
        label: 'Dwellings - Studio'
        desc: 'Number of studio units in the typology.'
        type: Number
        units: 'Dwellings'
      num_1br:
        label: 'Dwellings - 1 Bedroom'
        desc: 'Number of 1 bedroom units in the typology.'
        type: Number
        units: 'Dwellings'
      num_2br:
        label: 'Dwellings - 2 Bedroom'
        desc: 'Number of 2 bedroom units in the typology.'
        type: Number
        units: 'Dwellings'
      num_3plus:
        label: 'Dwellings - 3 Bedroom Plus'
        desc: 'Number of 3 bedroom units in the typology.'
        type: Number
        units: 'Dwellings'
      prpn_lawn:
        label: 'Proportion Extra Land - Lawn'
        desc: 'Proportion of extra land covered by lawn.'
        type: Number
        decimal: true
        classes:
          RESIDENTIAL:
            defaultValue: 0.15
      prpn_annu:
        label: 'Proportion Extra Land - Annual Plants'
        desc: 'Proportion of extra land covered by annual plants, such as flowers and veggies.'
        type: Number
        decimal: true
        classes:
          RESIDENTIAL:
            defaultValue: 0.1
      prpn_hardy:
        label: 'Proportion Extra Land - Hardy Plants'
        desc: 'Proportion of extra land covered by hardy or waterwise plants.'
        type: Number
        decimal: true
        classes:
          RESIDENTIAL:
            defaultValue: 0.35
      prpn_imper:
        label: 'Proportion Extra Land - Impermeable'
        desc: 'Proportion of extra land covered by pavement or another impermeable surface.'
        type: Number
        decimal: true
        classes:
          RESIDENTIAL:
            defaultValue: 0.4
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
        label: 'Energy - Heating'
        desc: 'Energy required for heating the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
      src_heat:
        label: 'Energy Source – Heating'
        desc: 'Energy source in the typology used for heating.'
        type: String
        allowedValues: EnergySources
      en_cool:
        label: 'Energy – Cooling'
        desc: 'Energy required for cooling the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
      en_light:
        label: 'Energy - Lighting'
        desc: 'Energy required for lighting the typology.'
        type: Number
        decimal: true
        units: Units.kWhyear
      en_hwat:
        label: 'Energy - Hot Water'
        desc: 'Energy required for hot water heating in the typology.'
        type: Number
        decimal: true
        units: Units.GJyear
      src_hwat:
        label: 'Energy Source - Hot Water'
        desc: 'Energy source in the typology used for hot water heating. Used to calculated CO2-e.'
        type: String
        allowedValues: EnergySources
      en_cook:
        label: 'Energy - Cooktop and Oven'
        desc: 'Energy required for cooking in the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        classes:
          RESIDENTIAL:
            defaultValue: 1956
    # TODO(aramk) Default value should be based on src_cook.
      src_cook:
        label: 'Energy Source - Cooktop and Oven'
        desc: 'Energy source in the typology used for cooking. Used to calculate CO2-e.'
        type: String
        allowedValues: EnergySources
        classes:
          RESIDENTIAL:
            defaultValue: 'Electricity'
      en_app:
        label: 'Energy - Appliances'
        desc: 'Energy required for powering appliances in the typology.'
        type: Number
        decimal: true
        units: Units.MJyear
        classes:
          RESIDENTIAL:
            defaultValue: 9749
      size_pv:
        label: 'PV System Size'
        desc: 'PV system size fitted on the typology.'
        type: Number
        decimal: true
        units: Units.kWhyear
        classes:
          RESIDENTIAL:
            defaultValue: 0
      en_pv:
        label: 'PV Energy Generation'
        desc: 'Energy generated by the fitted PV system.'
        type: Number
        decimal: true
        units: Units.kWh
      # TODO(aramk) Add needed project parameter
      # TODO(aramk) Make days in year a constant above.
        calc: '$energy_demand.size_pv * $renewable_energy.pv_output * 365'
      en_total:
        label: 'Energy - Total Operating'
        desc: 'Total operating energy from all energy uses.'
        type: Number
        decimal: true
        units: Units.MJyear
        calc: '$energy_demand.en_app + $energy_demand.en_cook + ($energy_demand.en_hwat * 1000) + ($energy_demand.en_light * 3.6) + $energy_demand.en_cool + $energy_demand.en_heat - ($energy_demand.en_pv * 3.6)'
  embodied_carbon:
    label: 'Embodied Carbon'
    items:
      e_co2_green:
        label: 'CO2 - Greenspace'
        desc: 'CO2 embodied in the greenspace portion of external land.'
        type: Number
        units: Units.kgco2
        calc: '($space.ext_land_l + $space.ext_land_a + $space.ext_land_h) * $embodied_carbon.landscaping.greenspace'
      e_co2_imp:
        label: 'CO2 - Impervious'
        desc: 'CO2 embodied in the impervious portion of external land.'
        type: Number
        units: Units.kgco2
        calc: '$space.ext_land_i * $embodied_carbon.landscaping.impermeable'
      e_co2_emb:
        label: 'CO2 - Total External Embodied'
        desc: 'CO2 embodied in the external impermeable surfaces.'
        type: Number
        units: Units.kgco2
        calc: '$embodied_carbon.e_co2_green * $embodied_carbon.e_co2_imp'
      i_co2_emb:
        label: 'CO2 - Internal Embodied'
        desc: 'CO2 embodied in the materials of the typology.'
        type: Number
        units: Units.kgco2
      t_co2_emb:
        label: 'CO2 - Total Embodied'
        desc: 'Total CO2 embodied in the property.'
        type: Number
        units: Units.kgco2
        calc: '$embodied_carbon.e_co2_emb * $embodied_carbon.i_co2_emb'
  operating_carbon:
    label: 'Operating Carbon'
    items:
      co2_heat:
        label: 'CO2 – Heating'
        desc: 'CO2 emissions due to heating the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: -> calcEnergyC02('energy_demand.src_heat', 'energy_demand.en_heat', @param)
      co2_cool:
        label: 'CO2 – Cooling'
        desc: 'CO2 emissions due to cooling the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
      # Convert kWh to MJ
        calc: '$energy_demand.en_cool * $operating_carbon.elec / 3.6'
      co2_light:
        label: 'CO2 - Lighting'
        desc: 'CO2-e emissions due to lighting the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$energy_demand.en_light * $operating_carbon.elec'
      co2_hwat:
        label: 'CO2 - Hot Water'
        desc: 'CO2-e emissions due to hot water heating in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: ->
          co2 = calcEnergyC02('energy_demand.src_hwat', 'energy_demand.en_hwat', @param)
          if co2? then co2 * 1000 else null
      co2_cook:
        label: 'CO2 - Cooktop and Oven'
        desc: 'CO2-e emissions due to cooking in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: -> calcEnergyC02('energy_demand.src_cook', 'energy_demand.en_cook', @param)
      co2_app:
        label: 'CO2 - Appliances'
        desc: 'CO2-e emissions due to powering appliances in the typology.'
        type: Number
        decimal: true
        units: Units.kgco2
      # Convert kWh to MJ
        calc: '$energy_demand.en_app * $operating_carbon.elec / 3.6'
      co2_op_tot:
        label: 'CO2 - Total Operating'
        desc: 'Total operating CO2 from all energy uses.'
        type: Number
        decimal: true
        units: Units.kgco2
        calc: '$operating_carbon.co2_heat + $operating_carbon.co2_cool + $operating_carbon.co2_light + $operating_carbon.co2_hwat + $operating_carbon.co2_cook + $operating_carbon.co2_app - ($energy_demand.en_pv * $operating_carbon.elec)'
  water_demand:
    label: 'Water Demand'
    items:
      i_wu_pot:
        label: 'Internal Water Use - Potable'
        desc: 'Internal potable water use of the typology.'
        type: Number
        decimal: true
        units: Units.kL
      i_wu_bore:
        label: 'Internal Water Use - Bore'
        desc: 'Internal bore water use of the typology.'
        type: Number
        decimal: true
        units: Units.kL
      i_wu_rain:
        label: 'Internal Water Use - Rain'
        desc: 'Internal rain water use of the typology.'
        type: Number
        decimal: true
        units: Units.kL
      i_wu_treat:
        label: 'Internal Water Use - Treated'
        desc: 'Internal treated water use of the typology.'
        type: Number
        decimal: true
        units: Units.kL
      i_wu_grey:
        label: 'Internal Water Use - Grey'
        desc: 'Internal grey water use of the typology.'
        type: Number
        decimal: true
        units: Units.kL
      i_wu_total:
        label: 'Internal Water Use - Total'
        desc: 'Total internal water use of the typology.'
        type: Number
        decimal: true
        units: Units.kL
        calc: '$water_demand.i_wu_pot + $water_demand.i_wu_bore + $water_demand.i_wu_rain + $water_demand.i_wu_treat + $water_demand.i_wu_grey'
      e_wd_lawn:
        label: 'External Water Demand - Lawn'
        desc: 'External water demand of lawn.'
        type: Number
        decimal: true
        units: Units.kL
        calc: '$space.ext_land_l * $external_water.demand_lawn'
      e_wd_ap:
        label: 'External Water Demand - Annual Plants'
        desc: 'External water demand of annual plants.'
        type: Number
        decimal: true
        units: Units.kL
        calc: '$space.ext_land_a * $external_water.demand_ap'
      e_wd_hp:
        label: 'External Water Demand - Hardy Plants'
        desc: 'External water demand of hardy plants.'
        type: Number
        decimal: true
        units: Units.kL
        calc: '$space.ext_land_h * $external_water.demand_hp'
      e_wd_total:
        label: 'External Water Demand - Total'
        desc: 'Total external water demand of the typology.'
        type: Number
        decimal: true
        units: Units.kL
        calc: '$water_demand.e_wd_lawn + $water_demand.e_wd_ap + $water_demand.e_wd_hp'
      e_wd_src:
        label: 'External Water Demand - Source'
        desc: 'Source of water for external water demand.'
        type: String
        allowedValues: WaterDemandSources
        classes:
          RESIDENTIAL:
            defaultValue: 'Potable'
      wu_pot_tot:
        label: 'Water Use - Total Potable'
        desc: 'Total potable water use for internal and external purposes.'
        type: Number
        decimal: true
        units: Units.kL
        calc: '$water_demand.i_wu_pot + IF($water_demand.e_wd_src, $water_demand.e_wd_total, 0)'
#        calc: (param) ->
#          # TODO(aramk) Convert this to a string by using an IF() function.
#          wu_pot_tot = 0
#          i_wu_pot = param('water_demand.i_wu_pot')
#          e_wd_total = param('water_demand.e_wd_total')
#          wu_pot_tot += i_wu_pot
#          e_wd_src = param('water_demand.e_wd_src')
#          if e_wd_src == 'Potable'
#            wu_pot_tot += e_wd_total
#          wu_pot_tot
      wd_total:
        label: 'Water Demand - Total'
        desc: 'Total water use for internal and external purposes.'
        type: Number
        decimal: true
        units: Units.kL
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
  financial:
    label: 'Financial'
    items:
      cost_land:
        label: 'Cost – Land Parcel'
        type: Number
        decimal: true
        desc: 'Value of the parcel of land.'
        units: Units.$
        calc: '$space.lotsize * $financial.land.price_land'
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
      # TODO(aramk) TOO COMPLEX! USE IF() FOR THIS.
        calc: '0'
      cost_op_g:
        label: 'Cost - Gas Usage'
        desc: 'Operating costs due to gas usage.'
        type: Number
        decimal: true
        units: Units.$
      # TODO(aramk) TOO COMPLEX! USE IF() FOR THIS.
        calc: '0'
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
        calc: '$financial.cost_op_e + $financial.cost_op_g'
  orientation:
    label: 'Orientation'
    items:
      azimuth:
        label: 'Azimuth'
        desc: 'Orientation of the typology with north as 0 degrees.'
        type: Number
        decimal: true
        units: 'Degrees'
      # TODO(aramk) Implement a function to get this
        calc: '0'
      eq_azmth_h:
        label: 'Azimuth Heating Energy Array'
        desc: 'Equation to predict heating energy use as a function of degrees azimuth.'
        type: String
      eq_azmth_c:
        label: 'Azimuth Cooling Energy Array'
        desc: 'Equation to predict cooling energy use as a function of degrees azimuth.'
        type: String
  parking:
    label: 'Parking'
    items:
      parking_sl:
        label: 'Parking Spaces - Street Level'
        desc: 'Number of street-level parking spaces.'
        type: Number
        units: 'Spaces'
      parking_ug:
        label: 'Parking Spaces - Underground'
        desc: 'Number of underground parking spaces.'
        type: Number
        units: 'Spaces'

####################################################################################################
# AUXILIARY - MUST BE DEFINED BEFORE USE
####################################################################################################

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

autoLabel = (field, id) ->
  label = field.label
  if label?
    label
  else
    label = id.replace('_', '')
    toTitleCase(label)

createCategorySchemaObj = (cat, catId, args) ->
  catSchemaFields = {}
  # For each field in each category
  for itemId, item of cat.items
    if item.items?
      itemFields = createCategorySchemaObj(item, itemId, args)
    else
      # TODO(aramk) Set the default to 0 for numbers.
      itemFields = _.extend({optional: true}, args.itemDefaults, item)
      autoLabel(itemFields, itemId)
      # If defaultValue is used, put it into "classes" to prevent SimpleSchema from storing this
      # value in the doc. We want to inherit this value at runtime for all classes, but not
      # persist it in multiple documents in case we want to change it later in the schema.
      # TODO(aramk) Check if this is intended behaviour.
      defaultValue = itemFields.defaultValue
      if defaultValue?
        classes = itemFields.classes ?= {}
        allClassOptions = classes.ALL ?= {}
        if allClassOptions.defaultValue?
          throw new Error('Default value specified on field and in classOptions - only use one.')
        allClassOptions.defaultValue = defaultValue
        delete itemFields.defaultValue
    catSchemaFields[itemId] = itemFields
  catSchema = new SimpleSchema(catSchemaFields)
  catSchemaArgs = _.extend({
    optional: false
    defaultValue: {}
  }, args.categoryDefaults, cat, {type: catSchema})
  autoLabel(catSchemaArgs, catId)
  delete catSchemaArgs.items
  catSchemaArgs

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
    catSchemaArgs = createCategorySchemaObj(cat, catId, args)
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
  hasPrefix: (id) -> @._rePrefix.test(id)

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

Typologies.getParameter = (obj, paramId) ->
  # Allow paramId to optionally contain the prefix.
  paramId = ParamUtils.removePrefix(paramId)
  # Allow obj to contain "parameters" map or be the map itself.
  target = obj.parameters ? obj ?= {}
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
    # TODO(aramk) defaultValue currently removed from schema field.
#    defaultValue = fieldSchema.defaultValue
    classes = fieldSchema.classes
    # NOTE: This does not look for official defaultValue in the schema, only in the class options.
    classDefaultValue = classes?[typologyClass]?.defaultValue
    allClassDefaultValue = classes?.ALL?.defaultValue
    defaultValue = classDefaultValue ? allClassDefaultValue

    #    if defaultValue? && classDefaultValue?
    #      console.warn('Field has both defaultValue and classes with defaultValue - using latter.')
    #      defaultValue = classDefaultValue

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

mergeDefaultParameters = (model, defaults) ->
  model.parameters ?= {}
  Setter.defaults(model.parameters, defaults)
  model

Typologies.mergeDefaults = (model) ->
  typologyClass = model.parameters.general?.class
  defaults = if typologyClass then Typologies.getDefaultParameterValues(typologyClass) else null
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
        units: Units.co2kWh
        defaultValue: 0.92
      gas:
        label: 'Carbon per kWh - Gas'
        type: Number
        decimal: true
        units: Units.co2kWh
        defaultValue: 0.229
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
          price_land:
            label: 'Land Value'
            type: Number
            desc: 'Land Value per Square Metre'
            units: Units.$m2
            defaultValue: 500
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
# TODO(aramk) Use these for src_cook.
#  energy_demand:
#    label: 'Energy Demand'
#    items:
#      en_cook_elec:
#        label: 'Cooktop and Oven - Electricity Demand'
#        desc: 'Energy required for cooking in a typology using electricity.'
#        type: Number
#        decimal: true
#        units: Units.MJyear
#        defaultValue: 1956
#      en_cook_gas:
#        label: 'Cooktop and Oven - Gas Demand'
#        desc: 'Energy required for cooking in a typology using gas.'
#        type: Number
#        decimal: true
#        units: Units.MJyear
#        defaultValue: 3366

ProjectParametersSchema = createCategoriesSchema
  categories: projectCategories

ProjectSchema = new SimpleSchema
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

@Projects = new Meteor.Collection 'project', schema: ProjectSchema
Projects.schema = ProjectSchema
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

Projects.getDefaultParameterValues = _.memoize ->
  values = {}
  forEachFieldSchema ProjectParametersSchema, (fieldSchema, paramId) ->
    # Default value is stored in the "classes" object to avoid being used by SimpleSchema.
    defaultValue = fieldSchema.classes?.ALL?.defaultValue
    if defaultValue?
      values[paramId] = defaultValue
  Typologies.unflattenParameters(values, false)

Projects.mergeDefaults = (model) ->
  defaults = Projects.getDefaultParameterValues()
  mergeDefaultParameters(model, defaults)
