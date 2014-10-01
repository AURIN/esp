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
        vertices: space?.geom_2d ? typologySpace?.geom_2d
        height: space?.height
        zIndex: 1
        displayMode: displayMode
        color: '#666'
        borderColor: '#000'

  _getMesh: (id) ->
    entity = Entities.getFlattened(id)
    meshFileId = Entities.getParameter(entity, 'space.geom_3d')
    if meshFileId
      Files.downloadJson(meshFileId)
    else
      meshDf = Q.defer()
      meshDf.resolve(null)
      meshDf.promise

  _buildMeshCollection: (id) ->
    df = Q.defer()
    geoEntity = AtlasManager.getEntity(id)
    @_getMesh(id).then (result) ->
      unless result
        df.resolve(null)
        return
      # Modify the ID of c3ml entities to allow reusing them for multiple collections.
      c3mls = result.c3mls
      _.each result.c3mls, (c3ml) ->
        # Hide by default and show after translating to the Lot.
        c3ml.show = false
        c3ml.id = id + ':' + c3ml.id
      try
        c3mlEntities = AtlasManager.renderEntities(c3mls)
      catch e
        console.error(e)
      entityIds = []
      _.each c3mlEntities, (c3mlEntity) ->
        mesh = null
        if c3mlEntity.getForm
          mesh = c3mlEntity.getForm()
          unless mesh
            return
        entityIds.push(c3mlEntity.getId())
      # Add c3mls to a single collection and use it as the mesh display mode for the
      # feature.
      require ['atlas/model/Collection'], (Collection) ->
        # TODO(aramk) Use dependency injection to prevent the need for passing manually.
        deps = geoEntity._bindDependencies({})
        collection = new Collection('collection-' + id, {entities: entityIds}, deps)
        df.resolve(collection)
    df.promise

  render: (entityId) ->
    df = Q.defer()
    geoEntity = AtlasManager.getEntity(entityId)
    if geoEntity
      AtlasManager.showEntity(entityId)
      df.resolve(geoEntity)
    else
      @toGeoEntityArgs(entityId).then (entityArgs) =>
        entity = Entities.getFlattened(entityId)
        # If the geoEntity was rendered using the Typology geometry, centre it based on the Lot.
        lot = Lots.findOne(entity.lot)
        unless lot
          AtlasManager.unrenderEntity(entityId)
          throw new Error('Rendered geoEntity does not have an accompanying lot.')
        lotId = lot._id
        require [
          'atlas/model/Feature',
          'atlas/model/Vertex'
        ], (Feature, Vertex) =>
          LotUtils.render(lotId).then (lotEntity) =>
            # Hide the entity initially to avoid showing the transition.
            entityArgs.show = false
            # Render the entity once the Lot has been rendered.
            geoEntity = AtlasManager.renderEntity(entityArgs)
            # Apply rotation based on the azimuth.
            azimuth = Entities.getParameter(entity, 'orientation.azimuth')
            geoEntity.setRotation(new Vertex(0, 0, azimuth)) if azimuth?
            # Mesh has not been rendered yet, so only position extrusion/footprint.
            unless geoEntity.getDisplayMode() == Feature.DisplayMode.MESH
              geoEntity.setCentroid(lotEntity.getCentroid())
            AtlasManager.showEntity(entityId)
            df.resolve(geoEntity)
            # Render the mesh afterwards to prevent long delays.
            @._buildMeshCollection(entityId).then (collection) ->
              unless collection
                return
              meshEntity = collection
              meshEntity.setCentroid(lotEntity.getCentroid())
              meshEntity.show();
              geoEntity.setForm(Feature.DisplayMode.MESH, meshEntity)
    df.promise
