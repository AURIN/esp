# TODO(aramk) Refactor with LotUtils

@EntityUtils =

  toGeoEntityArgs: (id) ->
    AtlasConverter.getInstance().then (converter) ->
      entity = Entities.getFlattened(id)
      typology = Typologies.findOne(entity.typology)
      space = entity.parameters.space
      typologySpace = typology.parameters.space
      displayMode = Session.get('entityDisplayMode')
      converter.toGeoEntityArgs
        id: id
#        mesh: mesh
        vertices: space.geom ? typologySpace.geom
        height: space.height
        zIndex: 1
        displayMode: displayMode
        color: '#666'
        borderColor: '#000'

  _getMesh: (id) ->
    meshDf = Q.defer()
    entity = Entities.getFlattened(id)
    meshFileId = Entities.getParameter(entity, 'space.mesh')
    unless meshFileId?
      meshDf.resolve(null)
    Meteor.call 'files/download/json', meshFileId, (err, data) ->
      console.log('download', arguments)
      if err
        meshDf.reject(err)
      else
        meshDf.resolve(data)
    meshDf.promise

  _buildMeshCollection: (id) ->
    df = Q.defer()
    geoEntity = AtlasManager.getEntity(id)
    @_getMesh(id).then (result) ->
      unless result
        df.resolve(null)
        return
      console.log('c3mls', result.c3mls)
      # Store a single geolocation and translate all c3ml entities by the difference between
      # this and the log geoEntity.
      c3mlBaseCentroid = null
      try
        c3mlEntities = AtlasManager.renderEntities(result.c3mls)
      catch e
        console.error(e)
      console.log('c3mlEntities', c3mlEntities)
      entityIds = []
      entityIdMap = {}
      _.each c3mlEntities, (c3mlEntity) ->
        mesh = null
        if c3mlEntity.getForm
          mesh = c3mlEntity.getForm()
          unless mesh
            return
        # TODO(aramk) Meshes still don't have centroid support so use geolocation for now.
        centroid = mesh.getGeoLocation()
        unless centroid
          return
        unless c3mlBaseCentroid
          c3mlBaseCentroid = centroid
        console.log('c3mlCentroid', centroid)
        entityId = c3mlEntity.getId()
        entityIds.push(entityId)
        entityIdMap[entityId] = true
      # Add c3mls to a single collection and use it as the mesh display mode for the
      # feature.
      require ['atlas/model/Collection'], (Collection) ->
        # TODO(aramk) Use dependency injection to prevent the need for passing manually.
        deps = geoEntity._bindDependencies({})
        collection = new Collection('collection-' + id, {entities: entityIds}, deps)
        df.resolve(collection: collection, centroid: c3mlBaseCentroid)
    df.promise

  render: (entityId) ->
    df = Q.defer()
    entity = AtlasManager.getEntity(entityId)
    if entity
      AtlasManager.showEntity(entityId)
      df.resolve(entity)
    else
      @toGeoEntityArgs(entityId).then (entityArgs) =>
        geoEntity = AtlasManager.renderEntity(entityArgs)
        # If the geoEntity was rendered using the Typology geometry, centre it based on the Lot.
        lot = Lots.findByEntity(entityId)
        unless lot
          AtlasManager.unrenderEntity(entityId)
          throw new Error('Rendered geoEntity does not have an accompanying lot.')
        lotId = lot._id
        LotUtils.render(lotId).then (lotEntity) =>
          lotCentroid = lotEntity.getCentroid()
          entityCentroidDiff = lotCentroid.subtract(geoEntity.getCentroid())
          geoEntity.translate(entityCentroidDiff)
          df.resolve(geoEntity)

          require ['atlas/model/Feature'], (Feature) =>
            # Render the mesh afterwards to prevent long delays.
            @._buildMeshCollection(entityId).then (result) ->
              meshEntity = result.collection
              centroid = result.centroid
              meshCentroidDiff = lotCentroid.subtract(centroid)
              meshEntity.translate(meshCentroidDiff)
              geoEntity.setForm(Feature.DisplayMode.MESH, meshEntity)

    df.promise
