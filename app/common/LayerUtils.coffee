bindMeteor = Meteor.bindEnvironment.bind(Meteor)

renderCount = new ReactiveVar(0)
incrementRenderCount = -> renderCount.set(renderCount.get() + 1)
decrementRenderCount = -> renderCount.set(renderCount.get() - 1)
FILL_COLOR = '#888'
BORDER_COLOR = '#333'

@LayerUtils =

  displayModeRenderEnabled: true
  displayModeRenderHandle: null
  displayModeDfs: null
  # A map of layer ID to a map of layer c3ml IDs to lot IDs - only for those intersecting.
  # intersectionCache: null
  # lotToLayerMap: null
  # lotPolyCache: null
  # layerPolyCache: null
  displayModeDirty: null
  displayModeHandles: null

  fromAsset: (args) ->
    args = Setter.merge({}, args)
    df = Q.defer()
    projectId = args.projectId ? Projects.getCurrentId()

    # Add heights to c3ml based on height property. Only keep polygons which we can use as
    # footprints.
    c3mls = []
    _.each args.c3mls, (c3ml) ->
      return unless AtlasConverter.sanitizeType(c3ml.type) == 'polygon'
      layerParams = c3ml.properties ? {}
      height = layerParams.height
      if height
        c3ml.height = parseFloat(height)
      c3mls.push(c3ml)

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

  render: (id, args) ->
    args = _.extend({
      renderDisplayMode: true
      showOnRender: true
    }, args)
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
      if args.showOnRender
        @show(id).then(
          -> df.resolve(geoEntity)
          df.reject
        )
      else
        df.resolve(geoEntity)
    else
      @_renderLayer(id).then(
        (geoEntity) =>
          PubSub.publish('layer/show', id)
          if args.renderDisplayMode
            @renderDisplayMode(id).then(
              -> df.resolve(geoEntity)
              df.reject
            )
          else
            df.resolve(geoEntity)
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
      c3mls = _.filter c3mls, (c3ml) -> AtlasConverter.sanitizeType(c3ml.type) != 'collection'
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

  # Hides footprint polygons in the layer which don't intersect with a non-development lot. If Lot
  # IDs are passed, only the footprint polygons which intersect with the lot are modified.
  renderDisplayMode: (id, lotIds) ->
    return Q.when() unless @displayModeRenderEnabled
    layer = Layers.findOne(id)
    displayMode = @getDisplayMode(id)
    emptyPromise = Q.when(null)
    # All other display modes don't require any extra handling
    return emptyPromise unless displayMode == 'nonDevExtrusion'
    
    dirty = @displayModeDirty
    # cache = @_setUpInterectionCache()
    return emptyPromise unless dirty[id]

    df = @displayModeDfs[id]
    return df.promise if df
    df = @displayModeDfs[id] = Q.defer()

    subsetLots = lotIds?
    unless lotIds
      lotIds = _.map Lots.findNotForDevelopment(), (lot) -> lot._id
    clearTimeout(@displayModeRenderHandle)
    @displayModeRenderHandle = setTimeout(
      =>
        requirejs ['subdiv/Polygon'], (Polygon) =>
          lotPromises = _.map lotIds, (lotId) -> LotUtils.render(lotId)
          Q.all(lotPromises).then (geoEntities) =>
            lotPolygons = _.map geoEntities, (geoEntity) ->
              polygon = new Polygon(GeometryUtils.toUtmVertices(geoEntity))
              polygon.id = geoEntity.getId()
              polygon
            footprintPolygons = {}
            # Prevent a deadlock by not waiting on display mode rendering when waiting for the
            # layer to render. Prevent showing the footprints on render if we are given a subset of
            # lots, since we don't want hidden non-intersecting footprints to be shown.
            @render(id, {
              renderDisplayMode: false
              showOnRender: !subsetLots
            }).then (collection) ->
              unless collection
                df.reject('Cannot render display mode - no layer entity')
                return
              collection.getEntities().forEach (footprintGeoEntity) ->
                return unless footprintGeoEntity.getVertices?
                footprintId = footprintGeoEntity.getId()
                footprintPolygons[footprintId] =
                    new Polygon(GeometryUtils.toUtmVertices(footprintGeoEntity))
              _.each footprintPolygons, (footprintPolygon, footprintId) ->
                intersectsLot = null
                _.some lotPolygons, (lotPolygon) ->
                  lotId = lotPolygon.id
                  lotIsNonDev =
                      !SchemaUtils.getParameterValue(Lots.findOne(lotId), 'general.develop')
                  intersects = footprintPolygon.intersects(lotPolygon)
                  # If a subset of the lots are provided, don't modify the visibility of
                  # non-intersecting footprints, since they are not affected.
                  if subsetLots && !intersects
                    return
                  else
                    intersectsLot = intersects && lotIsNonDev
                footprintGeoEntity = AtlasManager.getEntity(AtlasIdMap.getAppId(footprintId))
                # Ignore null value which indicates no changes should be made.
                if intersectsLot?
                  footprintGeoEntity.setVisibility(intersectsLot)
              delete dirty[id]
              df.resolve()
      1000
    )
    df.promise.fin =>
      delete @displayModeDfs[id]
    df.promise

  setUpDisplayMode: ->
    handles = @displayModeHandles = []
    dirty = @displayModeDirty
    @displayModeDfs = {}
    if dirty?
      return dirty
    dirty = @displayModeDirty = {}
    setDirty = (layer) =>
      dirty[layer._id] = true
      @renderDisplayMode(layer._id)
    setAllDirty = (lot) =>
      lotIds = if lot then [lot._id] else undefined
      Layers.findByProject().forEach (layer) =>
        dirty[layer._id] = true
        @renderDisplayMode(layer._id, lotIds)
    removeDirty = (doc) -> delete dirty[doc._id]

    # Any changes to layers and lots will make the layer re-render for the changed lots.
    handles.push Collections.observe(Layers.findByProject(), {
      added: setDirty
      changed: setDirty
      removed: removeDirty
    })
    handles.push Collections.observe(Lots.findByProject(), {
      added: setAllDirty
      changed: setAllDirty
      removed: setAllDirty
    })
    # Initially, all layers are dirty.
    setAllDirty()
    dirty

  destroyDisplayMode: ->
    _.each @displayModeHandles, (handle) -> handle.stop()
    @displayModeHandles = null
    @displayModeDirty = null
    dfs = @displayModeDfs
    _.each dfs, (df) -> df.reject()
    @displayModeDfs = null

  # _setUpInterectionCache: ->
  #   cache = @intersectionCache
  #   if cache?
  #     return cache
  #   cache = @intersectionCache ?= {}
  #   Collection.observe Layers, (doc) ->
  #     cache[doc._id] = {
  #       intersections: {}
  #       # A map of Lot IDs used to invalidate the cache when 
  #       lots: {}
  #     }
  #   Collection.observe Layers, (doc) ->
  #     cache[doc._id] = {}
  #   cache

  renderAllDisplayModes: (lotIds) ->
    dfs = []
    Layers.findByProject().forEach (layer) =>
      id = layer._id
      layerGeoEntity = AtlasManager.getEntity(id)
      if layerGeoEntity && layerGeoEntity.isVisible()
        dfs.push(@renderDisplayMode(id, lotIds))
    Q.all(dfs)

  setDisplayModeRenderEnabled: (enabled) -> @displayModeRenderEnabled = enabled

  unrender: (id) -> AtlasManager.unrenderEntity(id)

  show: (id) ->
    df = Q.defer()
    if AtlasManager.showEntity(id)
      @renderDisplayMode(id).then(
        ->
          PubSub.publish('layer/show', id)
          df.resolve()
        df.reject
      )
    else
      df.resolve()
    df.promise

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
    existingDisplayMode = @getDisplayMode(id)
    return unless existingDisplayMode != displayMode
    Layers.update(id, {$set: {'parameters.general.displayMode': displayMode}})

  getDisplayMode: (id) ->
    SchemaUtils.getParameterValue(Layers.findOne(id), 'general.displayMode') ? 'nonDevExtrusion'
