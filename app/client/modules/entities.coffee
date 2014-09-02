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
        vertices: space.geom_2d ? typologySpace.geom_2d
        height: space.height
        zIndex: 1
        displayMode: displayMode
        color: '#666'
        borderColor: '#000'

  _getMesh: (id) ->
    meshDf = Q.defer()
    entity = Entities.getFlattened(id)
    meshFileId = Entities.getParameter(entity, 'space.geom_3d')
    unless meshFileId?
      meshDf.resolve(null)
    Meteor.call 'files/download/json', meshFileId, (err, data) ->
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
      # Store a single geolocation and translate all c3ml entities by the difference between
      # this and the log geoEntity.
      c3mlBaseCentroid = null
      try
        c3mlEntities = AtlasManager.renderEntities(result.c3mls)
      catch e
        console.error(e)
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
    entity = Entities.findOne(entityId)
    geoEntity = AtlasManager.getEntity(entityId)
    if geoEntity
      AtlasManager.showEntity(entityId)
      df.resolve(geoEntity)
    else
      @toGeoEntityArgs(entityId).then (entityArgs) =>
        geoEntity = AtlasManager.renderEntity(entityArgs)
        # If the geoEntity was rendered using the Typology geometry, centre it based on the Lot.
        lot = Lots.findOne(entity.lot)
        unless lot
          AtlasManager.unrenderEntity(entityId)
          throw new Error('Rendered geoEntity does not have an accompanying lot.')
        lotId = lot._id
        require ['atlas/model/Feature'], (Feature) =>
          LotUtils.render(lotId).then (lotEntity) =>
            lotCentroid = lotEntity.getCentroid()
            unless geoEntity.getDisplayMode() == Feature.DisplayMode.MESH
              # TODO(aramk) Mesh doesn't have centroid yet.
              entityCentroidDiff = lotCentroid.subtract(geoEntity.getCentroid())
              geoEntity.translate(entityCentroidDiff)
            df.resolve(geoEntity)

            # Render the mesh afterwards to prevent long delays.
            @._buildMeshCollection(entityId).then (result) ->
              unless result
                return
              meshEntity = result.collection
              centroid = result.centroid
              meshCentroidDiff = lotCentroid.subtract(centroid)
              meshEntity.translate(meshCentroidDiff)
              geoEntity.setForm(Feature.DisplayMode.MESH, meshEntity)

    df.promise
