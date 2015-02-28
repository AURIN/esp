bindMeteor = Meteor.bindEnvironment.bind(Meteor)

renderCount = new ReactiveVar(0)
incrementRenderCount = -> renderCount.set(renderCount.get() + 1)
decrementRenderCount = -> renderCount.set(renderCount.get() - 1)

@LayerUtils =

  fromC3mls: (c3mls, args) ->
    args = Setter.merge({}, args)
    df = Q.defer()
    projectId = args.projectId ? Projects.getCurrentId()
    
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
      @show(id)
      df.resolve(geoEntity)
    else
      @_renderLayer(id).then(
        (geoEntity) =>
          PubSub.publish('layer/show', id)
          df.resolve(geoEntity)
        df.reject
      )
    df.promise

  _renderLayer: (id) ->
    df = Q.defer()
    @_getGeometry(id).then (data) ->
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
        require ['atlas/model/Collection'], (Collection) ->
          # TODO(aramk) Use dependency injection to prevent the need for passing manually.
          deps = c3mlEntities[0]._bindDependencies({})
          collection = new Collection(id, {entities: entityIds}, deps)
          df.resolve(collection)
      else
        df.resolve(c3mlEntities[0])
    df.promise

  show: (id) ->
    if AtlasManager.showEntity(id)
      PubSub.publish('layer/show', id)

  hide: (id) ->
    if AtlasManager.hideEntity(id)
      PubSub.publish('layer/hide', id)

  _getGeometry: (id) ->
    entity = Layers.findOne(id)
    meshFileId = SchemaUtils.getParameterValue(entity, 'space.geom_3d')
    if meshFileId
      Files.downloadJson(meshFileId)
    else
      meshDf = Q.defer()
      meshDf.resolve(null)
      meshDf.promise

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

