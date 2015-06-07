FILL_COLOR = '#888'
BORDER_COLOR = '#333'

@LayerUtils =

  fromAsset: (args) ->
    args = Setter.merge({}, args)
    df = Q.defer()
    projectId = args.projectId ? Projects.getCurrentId()
    inputC3mls = args.c3mls
    if inputC3mls.length > 2000
      return Q.reject('Cannot import assets containing more than 2000 objects.')

    # Add heights to c3ml based on height property. Only keep polygons which we can use as
    # footprints.
    c3mls = []
    _.each inputC3mls, (c3ml) ->
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
    Files.upload(file).then Meteor.bindEnvironment (fileObj) ->
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
          Logger.error('Failed to insert layer', err)
          df.reject(err)
        else
          console.log('Inserted layer comprised of ' + c3mls.length + ' c3mls')
          df.resolve(insertId)
    df.promise

  render: (id, args) ->
    args = _.extend({
      showOnRender: true
    }, args)
    df = @renderMap[id]
    if df && Q.isPending(df.promise) then return df.promise
    df = @renderMap[id] = Q.defer()
    @incrementRenderCount()
    df.promise.fin => @decrementRenderCount()
    
    model = Layers.findOne(id)
    space = model.parameters.space
    geom_2d = space.geom_2d
    geom_3d = space.geom_3d
    unless geom_2d || geom_3d
      df.resolve(null)
      @decrementRenderCount()
      return df.promise
    geoEntity = AtlasManager.getEntity(id)
    if geoEntity
      if args.showOnRender
        df.resolve @show(id).then -> geoEntity
      else
        df.resolve(geoEntity)
    else
      LotUtils.whenRenderingComplete().then =>
        renderPromise = @_renderLayer(id)
        renderPromise.fail(df.reject)
        renderPromise.then (geoEntity) =>
          PubSub.publish('layer/show', id)
          df.resolve(geoEntity)
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
      renderPromise = AtlasManager.renderEntities(c3mls)
      renderPromise.fail(df.reject)
      renderPromise.then (c3mlEntities) =>
        entityIds = _.map c3mlEntities, (entity) -> entity.getId()
        # Create a collection of all the added features.
        df.resolve AtlasManager.createCollection id,
          entities: entityIds
          color: FILL_COLOR
          borderColor: BORDER_COLOR
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
    requirejs ['subdiv/Polygon'], (Polygon) =>
      geoEntities =_.map lotIds, (lotId) -> AtlasManager.getEntity(lotId)
      lotPolygons = _.map geoEntities, (geoEntity) ->
        polygon = new Polygon(GeometryUtils.toUtmVertices(geoEntity))
        polygon.id = geoEntity.getId()
        polygon
      footprintPolygons = {}
      renderPromise = @render(id, {showOnRender: !subsetLots})
      renderPromise.fail(df.reject)
      renderPromise.then (collection) ->
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
          if intersectsLot? then footprintGeoEntity.setVisibility(intersectsLot)
        delete dirty[id]
        df.resolve()
    df.promise.fin => delete @displayModeDfs[id]
    df.promise

  setUpDisplayMode: ->
    handles = @displayModeHandles = []
    dirty = @displayModeDirty
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
    _.each @displayModeDfs, (df, id) -> df.reject()
    @displayModeDfs = {}

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

  hide: (id) -> if AtlasManager.hideEntity(id) then PubSub.publish('layer/hide', id)

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


  getRenderCount: -> @renderCount.get()

  resetRenderCount: -> @renderCount.set(0)

  setDisplayMode: (id, displayMode) ->
    existingDisplayMode = @getDisplayMode(id)
    return unless existingDisplayMode != displayMode
    Layers.update(id, {$set: {'parameters.general.displayMode': displayMode}})

  getDisplayMode: (id) ->
    SchemaUtils.getParameterValue(Layers.findOne(id), 'general.displayMode') ? 'nonDevExtrusion'

  incrementRenderCount: -> @renderCount.set(@renderCount.get() + 1)

  decrementRenderCount: -> @renderCount.set(@renderCount.get() - 1)

  beforeAtlasUnload: -> @reset()

  reset: ->
    @displayModeRenderEnabled = true
    # A map of layer ID to a map of layer c3ml IDs to lot IDs - only for those intersecting.
    # intersectionCache = null
    # lotToLayerMap = null
    # lotPolyCache = null
    # layerPolyCache = null
    @displayModeDirty = null
    @displayModeHandles = null
    @renderCount = new ReactiveVar(0)
    _.each @renderMap, (df, id) -> df.reject()
    @renderMap = {}

    @destroyDisplayMode()
    @resetRenderCount()

Meteor.startup -> LayerUtils.reset()
