# Defines a set of data migrations. All new versions are executed on startup.
Meteor.startup ->

  # NOTE: When migrating collections, ensure to use {validate: false} if the scheme has changed,
  # otherwise collection2 will prevent inserting/modifying docs which reference fields in the old
  # schema.

  Migrations.add
    version: 1
    up: ->
      migratedModelCount = 0
      # Schema changes.
      migrateGeom = (model, collection) ->
        geom = SchemaUtils.getParameterValue(model, 'space.geom')
        mesh = SchemaUtils.getParameterValue(model, 'space.mesh')
        if geom? || mesh?
          migratedModelCount += maybeRename(collection, model._id, {
            'parameters.space.geom': 'parameters.space.geom_2d'
            'parameters.space.mesh': 'parameters.space.geom_3d'
          })
      _.each Typologies.find().fetch(), (model) -> migrateGeom(model, Typologies)
      _.each Entities.find().fetch(), (model) -> migrateGeom(model, Entities)
      _.each Lots.find().fetch(), (model) -> migrateGeom(model, Lots)
      Logger.info('Migrated', migratedModelCount, 'models')

  Migrations.add
    version: 2
    up: ->
      migratedModelCount = 0
      # Schema changes.
      migrateProject = (model) ->
        Projects.direct.insert(model)
        migratedModelCount++
      OldProjects = new Meteor.Collection 'project'
      _.each OldProjects.find().fetch(), (model) -> migrateProject(model)
      Logger.info('Migrated', migratedModelCount, 'models')

  Migrations.add
    version: 3
    up: ->
      migratedModelCount = 0
      # Replaced parameters.general.creator to author. Since no users existed beforehand, set the
      # username as 'admin'.
      _.each Projects.find().fetch(), (model) ->
        migratedModelCount += Projects.direct.update({_id: model._id}, {
          $set:
            author: 'admin'
          $unset:
            'general.creator': null
        }, {validate: false})
      Logger.info('Migrated', migratedModelCount, 'projects to use author field.')

  Migrations.add
    version: 4
    up: ->
      migratedModelCount = 0
      # Add required "description" field for all models as a blank string.
      _.each [Typologies, Projects], (collection) ->
        _.each collection.find().fetch(), (model) ->
          return if model.desc?
          migratedModelCount += collection.direct.update({_id: model._id}, {
            $set:
              desc: '...'
          }, {validate: false})
      Logger.info('Migrated', migratedModelCount, 'models by adding description field.')

  Migrations.add
    version: 5
    up: ->
      migratedModelCount = 0
      # Add Project#isTemplate as false.
      Projects.find().forEach (model) ->
        return if model.isTemplate?
        migratedModelCount += Projects.direct.update({_id: model._id}, {
          $set:
            isTemplate: false
        }, {validate: false})
      Logger.info('Migrated', migratedModelCount, 'projects by adding isTemplate field.')

  Migrations.add
    version: 6
    up: ->
      migratedModelCount = 0
      Projects.find().forEach (project) ->
        _.each [Typologies, Entities], (collection) ->
          collection.findByProject(project._id).forEach (model) ->
            migratedModelCount += maybeRename(collection, model._id, {
              'parameters.energy_demand.en_heat': 'parameters.energy_demand.therm_en_heat'
              'parameters.energy_demand.en_cool': 'parameters.energy_demand.therm_en_cool'
            })
      Logger.info('Migrated', migratedModelCount, 'models to COP and EER fields.')

  Migrations.add
    version: 7
    up: ->
      migratedModelCount = 0
      fieldsMap =
        'energy_demand.en_hwat': 'energy_demand.hw_intensity'
        'water_demand.i_wu_pot': 'water_demand.i_wu_intensity_occ'
        'water_demand.i_wu_bore': 'water_demand.i_wu_intensity_bore'
        'water_demand.i_wu_rain': 'water_demand.i_wu_intensity_rain'
        'water_demand.i_wu_treat': 'water_demand.i_wu_intensity_treat'
        'water_demand.i_wu_grey': 'water_demand.i_wu_intensity_grey'
      prefix = 'parameters.'
      Projects.find().forEach (project) ->
        _.each [Typologies, Entities], (collection) ->
          collection.findByProject(project._id).forEach (model) ->
            $set = {}
            $unset = {}
            _.each fieldsMap, (intensityField, valueField) ->
              intensityField = prefix + intensityField
              valueField = prefix + valueField
              value = SchemaUtils.getParameterValue(model, valueField)
              occupants = SchemaUtils.getParameterValue(model, 'space.occupants')
              if value?
                $set[intensityField] = if occupants != 0 then value / occupants else 0
                $unset[valueField] = null
            migratedModelCount += maybeUpdate(collection, model._id, $set, $unset)
      Logger.info('Migrated', migratedModelCount, 'models to water use intensity fields.')

  Migrations.add
    version: 8
    up: ->
      migratedModelCount = 0
      fieldsMap =
        'embodied_carbon.i_co2_emb': 'embodied_carbon.i_co2_emb_intensity'
      prefix = 'parameters.'
      gfaParamId = 'space.gfa_t'
      Projects.find().forEach (project) ->
        _.each [Typologies, Entities], (collection) ->
          collection.findByProject(project._id).forEach (model) ->
            EntityUtils.evaluate(model, gfaParamId)
            $set = {}
            $unset = {}
            _.each fieldsMap, (intensityField, valueField) ->
              intensityField = prefix + intensityField
              valueField = prefix + valueField
              value = SchemaUtils.getParameterValue(model, valueField)
              gfa = SchemaUtils.getParameterValue(model, 'space.gfa_t')
              if value?
                $set[intensityField] = if gfa != 0 then value / gfa else 0
                $unset[valueField] = null
            migratedModelCount += maybeUpdate(collection, model._id, $set, $unset)
      Logger.info('Migrated', migratedModelCount, 'models to internal embodied co2 intensity.')

  Migrations.add
    version: 9
    up: ->
      migratedModelCount = 0
      fieldsMap =
        'energy_demand.en_hwat': 'energy_demand.hw_intensity'
      prefix = 'parameters.'
      Projects.find().forEach (project) ->
        _.each [Typologies, Entities], (collection) ->
          collection.findByProject(project._id).forEach (model) ->
            $set = {}
            $unset = {}
            _.each fieldsMap, (intensityField, valueField) ->
              intensityField = prefix + intensityField
              valueField = prefix + valueField
              intensity = SchemaUtils.getParameterValue(model, intensityField)
              occupants = SchemaUtils.getParameterValue(model, 'space.occupants')
              if intensity?
                $set[valueField] = intensity * occupants
                $unset[intensityField] = null
            migratedModelCount += maybeUpdate(collection, model._id, $set, $unset)
      Logger.info('Migrated', migratedModelCount, 'models to hot water energy demand.')

  Migrations.add
    version: 10
    up: ->
      migratedModelCount = 0
      Projects.find().forEach (project) ->
        _.each [Typologies, Entities], (collection) ->
          collection.findByProject(project._id).forEach (model) ->
            migratedModelCount += maybeRename(collection, model._id, {
              'parameters.water_demand.i_wu_intensity_pot': 'parameters.water_demand.i_wu_intensity_occ'
              'parameters.water_demand.i_wu_intensity': 'parameters.water_demand.i_wu_intensity_m2'
            })
      Logger.info('Migrated', migratedModelCount, 'models by renaming internal water use intensity fields.')

  Migrations.add
    version: 11
    up: ->
      migratedModelCount = 0
      Projects.find().forEach (project) ->
        _.each [Typologies, Entities], (collection) ->
          SchemaUtils.removeCalcFields(collection)
          migratedModelCount += collection.find().count()
      Logger.info('Migrated', migratedModelCount, 'models by removing calculated fields.')

  Migrations.add
    version: 12
    up: ->
      migratedModelCount = 0
      Projects.find().forEach (project) ->
        _.each [Typologies, Entities], (collection) ->
          collection.findByProject(project._id).forEach (model) ->
            migratedModelCount += maybeRename(collection, model._id, {
              'parameters.energy_demand.thermal_heat': 'parameters.energy_demand.therm_en_heat'
              'parameters.energy_demand.thermal_cool': 'parameters.energy_demand.therm_en_cool'
            })
      Logger.info('Migrated', migratedModelCount, 'models by renaming internal water use intensity fields.')

  Migrations.add
    version: 13
    up: ->
      migratedModelCount = 0
      _.each Lots.findWithMissingEntities(), (lotId) ->
        Lots.update lotId,
          $unset:
            entity: null
        migratedModelCount++
      Logger.info('Migrated', migratedModelCount, 'models by removing missing entity references in lots.')

  Migrations.add
    version: 14
    up: ->
      migratedModelCount = 0
      # Adds a dateModified value set to the current date for every project without one.
      _.each Projects.find().fetch(), (project) ->
        return if project.dateModified?
        migratedModelCount += Projects.update(project._id, {
          $set:
            dateModified: moment().toDate()
        }, {validate: false})
      Logger.info('Migrated', migratedModelCount, 'projects to use dateModified field.')

  maybeUpdate = (collection, id, $set, $unset) ->
    # Prevent updating if the $set or $unset are empty to prevent MongoDB errors.
    modifier = {}
    if Object.keys($set).length > 0
      modifier.$set = $set
    if Object.keys($unset).length > 0
      modifier.$unset = $unset
    return 0 if Object.keys(modifier).length == 0
    collection.direct.update({_id: id}, modifier, {validate: false})

  maybeRename = (collection, id, $rename) ->
    # Prevent renaming non-existent fields of a doc to prevent MondoDB errors.
    $rename = Setter.clone($rename)
    doc = collection.findOne(id)
    doc = Objects.flattenProperties(doc)
    return 0 unless doc?
    _.each $rename, (repl, fieldId) ->
      unless doc[fieldId]?
        delete $rename[fieldId]
    return 0 if Object.keys($rename).length == 0
    # Filtering can cause the $rename to be empty and remove all fields.
    collection.direct.update({_id: id}, {$rename: $rename}, {validate: false, filter: false})

  Logger.info('Migrating to latest version...')
  Migrations.migrateTo('latest')
