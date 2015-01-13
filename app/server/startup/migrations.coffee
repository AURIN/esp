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
          collection.update(model._id, {
            $rename:
              'parameters.space.geom': 'parameters.space.geom_2d'
              'parameters.space.mesh': 'parameters.space.geom_3d'
          }, {validate: false})
          migratedModelCount++
      _.each Typologies.find().fetch(), (model) -> migrateGeom(model, Typologies)
      _.each Entities.find().fetch(), (model) -> migrateGeom(model, Entities)
      _.each Lots.find().fetch(), (model) -> migrateGeom(model, Lots)
      console.log('Migrated', migratedModelCount, 'models')

  Migrations.add
    version: 2
    up: ->
      migratedModelCount = 0
      # Schema changes.
      migrateProject = (model) ->
        Projects.insert(model)
        migratedModelCount++
      OldProjects = new Meteor.Collection 'project'
      _.each OldProjects.find().fetch(), (model) -> migrateProject(model)
      console.log('Migrated', migratedModelCount, 'models')

  Migrations.add
    version: 3
    up: ->
      migratedModelCount = 0
      # Replaced parameters.general.creator to author. Since no users existed beforehand, set the
      # username as 'admin'.
      _.each Projects.find().fetch(), (model) ->
        migratedModelCount += Projects.update(model._id, {
          $set:
            author: 'admin'
          $unset:
            'general.creator': null
        }, {validate: false})
      console.log('Migrated', migratedModelCount, 'projects to use author field.')

  Migrations.add
    version: 4
    up: ->
      migratedModelCount = 0
      # Add required "description" field for all models as a blank string.
      _.each [Typologies, Projects], (collection) ->
        _.each collection.find().fetch(), (model) ->
          return if model.desc?
          migratedModelCount += collection.update(model._id, {
            $set:
              desc: '...'
          }, {validate: false})
      console.log('Migrated', migratedModelCount, 'models by adding description field.')

  Migrations.add
    version: 5
    up: ->
      migratedModelCount = 0
      # Add Project#isTemplate as false.
      Projects.find().forEach (model) ->
        return if model.isTemplate?
        migratedModelCount += Projects.update(model._id, {
          $set:
            isTemplate: false
        }, {validate: false})
      console.log('Migrated', migratedModelCount, 'projects by adding isTemplate field.')

  console.log('Migrating to latest version...')
  Migrations.migrateTo('latest')
