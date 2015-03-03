bindMeteor = Meteor.bindEnvironment.bind(Meteor)

renderCount = new ReactiveVar(0)
incrementRenderCount = -> renderCount.set(renderCount.get() + 1)
decrementRenderCount = -> renderCount.set(renderCount.get() - 1)
FILL_COLOR = '#888'
BORDER_COLOR = '#333'

@LayerUtils =

  fromAsset: (args) ->
    args = Setter.merge({}, args)
    df = Q.defer()
    projectId = args.projectId ? Projects.getCurrentId()

    # Add heights to c3ml based on height property. Only keep polygons which we can use as
    # footprints.
    c3mls = []
    _.each args.c3mls, (c3ml) ->
      return unless c3ml.type == 'polygon'
      layerParams = c3ml.properties ? {}
      height = layerParams.height
      if height
        c3ml.height = parseFloat(height)

    args.name ?= args.filename ? c3mls[0]?.id
    doc = {c3mls: c3mls, project: projectId}
    docString = JSON.stringify(doc)
    file = new FS.File()
    file.attachData(Arrays.arrayBufferFromString(docString), type: 'application/json')
    Files.upload(file).then bindMeteor (fileObj) ->
      # TODO(aramk) For now, using any random ID.
      name = args.name
      model =
        name: name
        project: projectId
        parameters:
          space:
            # TODO(aramk) This is no longer just for 3d - could be any geometry.
            geom_3d: fileObj._id
      Layers.insert model, (err, insertId) ->
        if err
          console.error('Failed to insert layer', err)
          df.reject(err)
        else
          console.log('Inserted layer comprised of ' + c3mls.length + ' c3mls')
          df.resolve(insertId)
    df.promise

  render: (id) ->
    df = Q.defer()
    incrementRenderCount()
    df.promise.fin -> decrementRenderCount()
    model = Layers.findOne(id)
    space = model.parameters.space
    geom_2d = space.geom_2d
    geom_3d = space.geom_3d
    unless geom_2d || geom_3d
      df.resolve(null)
      decrementRenderCount()
      return df.promise
    geoEntity = AtlasManager.getEntity(id)
    if geoEntity
      @show(id).then(
        -> df.resolve(geoEntity)
        df.reject
      )
    else
      @_renderLayer(id).then(
        (geoEntity) =>
          PubSub.publish('layer/show', id)
          @renderDisplayMode(id).then(
            -> df.resolve(geoEntity)
            df.reject
          )
        df.reject
      )
    df.promise

  _renderLayer: (id) ->
    df = Q.defer()
    @_getGeometry(id).then (data) =>
      unless data
        df.resolve(null)
        return
      # renderEntities() needed to parse c3ml.
      c3mls = data.c3mls
      unless c3mls
        c3mls = [data]
      # Ignore all collections in the c3ml, since they don't affect visualisation of the layer.
      c3mls = _.filter c3mls, (c3ml) -> c3ml.type != 'collection'
      if c3mls.length == 1
        # Ensure the ID of the layer is assigned if only a single entity rendered.
        c3mls[0].id = id
      c3mlEntities = AtlasManager.renderEntities(c3mls)
      if c3mlEntities.length > 1
        entityIds = _.map c3mlEntities, (entity) -> entity.getId()
        # Create a collection of all the added features.
        requirejs ['atlas/model/Collection'], (Collection) =>
          # TODO(aramk) Use dependency injection to prevent the need for passing manually.
          deps = c3mlEntities[0]._bindDependencies({})
          data = {entities: entityIds, color: FILL_COLOR, borderColor: BORDER_COLOR}
          collection = new Collection(id, data, deps)
          df.resolve(collection)
      else
        df.resolve(c3mlEntities[0])
    df.promise

  renderDisplayMode: (id) ->
    df = Q.defer()
    layer = Layers.findOne(id)
    displayMode = @getDisplayMode(id)
    # All other display modes don't require any extra handling
    return Q.when(null) unless displayMode == 'nonDevExtrusion'
    requirejs ['subdiv/Polygon'], (Polygon) ->
      devLotPolygons = _.map Lots.findNotForDevelopment(), (lot) ->
        new Polygon(GeometryUtils.toUtmVertices(AtlasManager.getEntity(lot._id)))
      footprintPolygons = {}
      collection = AtlasManager.getEntity(id)
      collection.getEntities().forEach (footprintGeoEntity) ->
        return unless footprintGeoEntity.getVertices?
        footprintId = footprintGeoEntity.getId()
        footprintPolygons[footprintId] =
            new Polygon(GeometryUtils.toUtmVertices(footprintGeoEntity))
      _.each footprintPolygons, (footprintPolygon, footprintId) ->
        intersectsLot = _.some devLotPolygons, (devLotPolygon) ->
          footprintPolygon.intersects(devLotPolygon)
        footprintGeoEntity = AtlasManager.getEntity(footprintId)
        footprintGeoEntity.setVisibility(intersectsLot)
      df.resolve()
    df.promise

  renderAllDisplayModes: ->
    dfs = []
    Layers.findByProject().forEach (layer) =>
      id = layer._id
      layerGeoEntity = AtlasManager.getEntity(id)
      if layerGeoEntity && layerGeoEntity.isVisible()
        dfs.push(@renderDisplayMode(id))
    Q.all(dfs)

  unrender: (id) -> AtlasManager.unrenderEntity(id)

  show: (id) ->
    if AtlasManager.showEntity(id)
      @renderDisplayMode(id).then -> PubSub.publish('layer/show', id)

  hide: (id) ->
    if AtlasManager.hideEntity(id)
      PubSub.publish('layer/hide', id)

  _getGeometry: (id) ->
    entity = Layers.findOne(id)
    meshFileId = SchemaUtils.getParameterValue(entity, 'space.geom_3d')
    if meshFileId
      Files.downloadJson(meshFileId)
    else
      Q.when(null)

  renderAll: ->
    renderDfs = []
    models = Layers.findByProject().fetch()
    _.each models, (model) => renderDfs.push(@render(model._id))
    Q.all(renderDfs)

  getSelectedIds: ->
    # Use the selected entities, or all entities in the project.
    entityIds = AtlasManager.getSelectedFeatureIds()
    # Filter GeoEntity objects which are not project entities.
    _.filter entityIds, (id) -> Layers.findOne(id)

  getRenderCount: -> renderCount.get()

  resetRenderCount: -> renderCount.set(0)

  setDisplayMode: (id, displayMode) ->
    Layers.update(id, {$set: {'parameters.general.displayMode': displayMode}})

  getDisplayMode: (id) ->
    SchemaUtils.getParameterValue(Layers.findOne(id), 'general.displayMode') ? 'nonDevExtrusion'
