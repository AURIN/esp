# TODO(aramk) Refactor with LotUtils

_renderQueue = null
Meteor.startup ->
  _renderQueue = new DeferredQueueMap()

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
      _.each c3mls, (c3ml) ->
        # Hide by default and show after translating to the Lot.
        c3ml.show = false
        c3ml.id = id + ':' + c3ml.id
      try
        c3mlEntities = AtlasManager.renderEntities(c3mls)
      catch e
        console.error('Error when rendering mesh entities', e)
      ids = []
      _.each c3mlEntities, (c3mlEntity) ->
        mesh = null
        if c3mlEntity.getForm
          mesh = c3mlEntity.getForm()
          ids.push(c3mlEntity.getId()) if mesh
      # Add c3mls to a single collection and use it as the mesh display mode for the
      # feature.
      require ['atlas/model/Collection'], (Collection) ->
        # TODO(aramk) Use dependency injection to prevent the need for passing manually.
        deps = geoEntity._bindDependencies({})
        collection = new Collection('collection-' + id, {entities: ids}, deps)
        df.resolve(collection)
    df.promise

  render: (id) -> _renderQueue.add(id, => @_render(id))

  _render: (id) ->
    df = Q.defer()
    geoEntity = AtlasManager.getEntity(id)
    if geoEntity
      AtlasManager.showEntity(id)
      df.resolve(geoEntity)
    else
      @toGeoEntityArgs(id).then (entityArgs) =>
        entity = Entities.getFlattened(id)
        # If the geoEntity was rendered using the Typology geometry, centre it based on the Lot.
        lot = Lots.findOne(entity.lot)
        unless lot
          AtlasManager.unrenderEntity(id)
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
            # unless geoEntity.getDisplayMode() == Feature.DisplayMode.MESH
            #   geoEntity.setCentroid(lotEntity.getCentroid())
            AtlasManager.showEntity(id)
            @._buildMeshCollection(id).then (collection) ->
              if collection
                meshEntity = collection
                # meshEntity.setCentroid(lotEntity.getCentroid())
                geoEntity.setForm(Feature.DisplayMode.MESH, meshEntity)
              # Ensure all forms have the same centroid.
              _.each Feature.DisplayMode, (displayMode) ->
                form = geoEntity.getForm(displayMode)
                form.setCentroid(lotEntity.getCentroid()) if form
              df.resolve(geoEntity)
    df.promise
