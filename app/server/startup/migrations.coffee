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
        geom = collection.getParameter(model, 'space.geom')
        mesh = collection.getParameter(model, 'space.mesh')
        if geom? || mesh?
          collection.update(model._id, {
            $rename:
              'parameters.space.geom': 'parameters.space.geom_2d'
              'parameters.space.mesh': 'parameters.space.geom_3d'
          }, {
            validate: false
          })
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

  console.log('Migrating to latest version...')
  Migrations.migrateTo('latest')
