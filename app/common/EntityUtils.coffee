# Defines a set of overrides to hooks and additional methods to EntityUtils, which is defined in
# urbanetic:bismuth-utility.

evalEngine = null
getEvalEngine = -> evalEngine ?= new EvaluationEngine(schema: Entities.simpleSchema())
FILL_COLOR = '#fff'
BORDER_COLOR = '#666'

_.extend EntityUtils,

  evaluate: (entity, paramIds) ->
    paramIds = if Types.isArray(paramIds) then paramIds else [paramIds]
    typologyClass = Entities.getTypologyClass(entity)
    Entities.getFlattened(entity)
    getEvalEngine().evaluate(model: entity, paramIds: paramIds, typologyClass: typologyClass)

  toGeoEntityArgs: (id, args) ->
    df = Q.defer()
    AtlasConverter.getInstance().then Meteor.bindEnvironment (converter) =>
      entity = Entities.getFlattened(id)
      typology = Typologies.findOne(entity.typology)
      typologyClass = Entities.getTypologyClass(id)
      space = entity.parameters.space
      typologySpace = typology.parameters.space
      displayMode = args?.displayMode ? @getDisplayMode(id)
      args = _.extend({
        id: id
        vertices: space?.geom_2d ? typologySpace?.geom_2d
        height: space?.height ? 5
        zIndex: 1
        displayMode: displayMode
        style:
          fillColor: FILL_COLOR
          borderColor: BORDER_COLOR
      }, args)
      if typologyClass == 'PATHWAY'
        widthParamId = 'space.width'
        getEvalEngine()
            .evaluate(model: entity, paramIds: [widthParamId], typologyClass: typologyClass)
        args.width = SchemaUtils.getParameterValue(entity, widthParamId)
        args.style.fillColor = '#000'
      df.resolve converter.toGeoEntityArgs(args)
    df.promise

  _getModel: (id) -> Entities.getFlattened(id)

  _buildGeometryFromFile: (id, paramId) ->
    entity = Entities.getFlattened(id)
    fileId = SchemaUtils.getParameterValue(entity, paramId)
    unless fileId
      return Q.when(null)
    collectionId = id + '-' + paramId
    style =
      fillColor: FILL_COLOR
      borderColor: BORDER_COLOR
    GeometryUtils.buildGeometryFromFile fileId,
      collectionId: collectionId
      style: style
      show: false

  _getRenderCentroid: (id) ->
    df = Q.defer()
    entity = Entities.findOne(id)
    position = SchemaUtils.getParameterValue(entity, 'space.position')
    if position
      requirejs [
        'atlas/model/GeoPoint'
      ], Meteor.bindEnvironment (GeoPoint) -> df.resolve new GeoPoint(position)
    else
      @_renderLot(id).then Meteor.bindEnvironment (lotEntity) ->
        # If the geoEntity was rendered using the Typology geometry, centre it based on the Lot.
        df.resolve lotEntity.getCentroid()
    df.promise

  _render: (id) ->
    df = Q.defer()
    @incrementRenderCount()
    df.promise.fin => @decrementRenderCount()
    resolve = (geoEntity) ->
      if geoEntity
        geoEntity.ready().then -> df.resolve(geoEntity)
      else
        df.resolve(geoEntity)
    geoEntity = AtlasManager.getEntity(id)
    # All the geometry added during rendering. If rendering fails, these are all discarded.
    addedGeometry = []
    if geoEntity
      AtlasManager.showEntity(id)
      resolve(geoEntity)
    else
      entity = Entities.getFlattened(id)
      geom_2d = SchemaUtils.getParameterValue(entity, 'space.geom_2d')
      azimuth = SchemaUtils.getParameterValue(entity, 'orientation.azimuth')
      offset = SchemaUtils.getParameterValue(entity, 'space.offset')

      typologyClass = Entities.getTypologyClass(id)
      isPathway = typologyClass == 'PATHWAY'

      WKT.getWKT Meteor.bindEnvironment (wkt) =>
        isWKT = wkt.isWKT(geom_2d)
        geometryDfs = [@_render2dGeometry(id)]
        # TODO(aramk) We cannot render 3D meshes on the server for exporting yet.
        unless isPathway || Meteor.isServer
          geometryDfs.push(@_render3dGeometry(id))
        geometryPromises = Q.all(geometryDfs)
        geometryPromises.fail(df.reject)
        geometryPromises.then Meteor.bindEnvironment (geometries) =>
          _.each geometries, (geometry) -> addedGeometry.push(geometry) if geometry
          if isPathway
            geoEntity = geometries[0]
            # A pathway doesn't have any 3d geometry or a lot.
            @_setUpEntity(geoEntity)
            resolve(geoEntity)
            return
          centroidPromise = @_getRenderCentroid(id)
          centroidPromise.fail(df.reject)
          centroidPromise.then Meteor.bindEnvironment (centroid) =>
            requirejs [
              'atlas/model/Feature',
              'atlas/model/GeoEntity',
              'atlas/model/Vertex'
            ], Meteor.bindEnvironment (Feature, GeoEntity, Vertex) =>

              # Precondition: 2d geometry is a required for entities.
              entity2d = geometries[0]
              entity3d = geometries[1]
              unless entity2d || entity3d
                # If the entity belongs to an Open Space precinct, generate an empty GeoEntity
                # to remove special cases.
                if typologyClass == 'OPEN_SPACE'
                  @_getBlankFeatureArgs(id).then Meteor.bindEnvironment (entityArgs) =>
                    resolve(AtlasManager.renderEntity(entityArgs))
                else
                  resolve(null)
                return

              # This feature will be used for rendering the 2d geometry as the
              # footprint/extrusion and the 3d geometry as the mesh.
              geoEntityDf = Q.defer()
              if isWKT
                geoEntityDf.resolve(entity2d)
              else
                # If we construct the 2d geometry from a collection of entities rather than
                # WKT, the geometry is a collection rather than a feature. Create a new
                # feature to store both 2d and 3d geometries.
                blankFeaturePromise = @_getBlankFeatureArgs(id)
                blankFeaturePromise.fail(geoEntityDf.reject)
                blankFeaturePromise.then Meteor.bindEnvironment (args) ->
                  geoEntity = AtlasManager.renderEntity(args)
                  addedGeometry.push(geoEntity)
                  if entity2d
                    geoEntity.setForm(Feature.DisplayMode.FOOTPRINT, entity2d)
                    args.height? && entity2d.setHeight(args.height)
                    args.elevation? && entity2d.setElevation(args.elevation)
                  geoEntityDf.resolve(geoEntity)
              geoEntityDf.promise.fail(df.reject)
              geoEntityDf.promise.then Meteor.bindEnvironment (geoEntity) =>
                if entity3d
                  geoEntity.setForm(Feature.DisplayMode.MESH, entity3d)
                formPromises = []
                _.each geoEntity.getForms(), (form) ->
                  unless Meteor.isServer
                    # Show the entity to ensure we can transform the rendered models. GLTF
                    # meshes need to be rendered before we can determine their centroid.
                    # TODO(aramk) Build the geometry without having to show it.
                    form.show()
                    form.hide()
                  formPromises.push form.ready().then Meteor.bindEnvironment ->
                    # Apply rotation based on the azimuth. Use the lot centroid since the
                    # centroid may not be updated yet for certain models (e.g. GLTF meshes).
                    currentCentroid = form.getCentroid()
                    # Perform this after getting the centroid to avoid rebuiding the
                    # primitive for GLTF meshes, which would require another ready() call.
                    form.setCentroid(centroid)
                    newCentroid = centroid.clone()
                    # Set the elevation to the same as the current elevation to avoid any
                    # movement in the elevation axis.
                    newCentroid.elevation = currentCentroid.elevation
                    form.setRotation(new Vertex(0, 0, azimuth), newCentroid) if azimuth?
                allFormPromises = Q.all(formPromises)
                allFormPromises.fail(df.reject)
                allFormPromises.then Meteor.bindEnvironment =>
                  onEntityReady = =>
                    geoEntity.setDisplayMode @getDisplayMode(id)
                    unless Meteor.isServer then geoEntity.show()
                    @_setUpEntity(geoEntity)
                    resolve(geoEntity)
                  if offset?
                    # Translate the local offset to a global geographic coordinate.
                    offsetVertex = {x: offset.eastern, y: offset.northern}
                    utmOffsetPromise = GeometryUtils.getUtmOffsetGeoPoint(centroid, offsetVertex)
                    utmOffsetPromise.fail (err) Meteor.bindEnvironment ->
                      Logger.error('Failed to offset entity', id, err)
                      onEntityReady()
                    utmOffsetPromise.then Meteor.bindEnvironment (result) ->
                      # We must display the GeoEntity before setting the centroid will take
                      # effect.
                      onEntityReady()
                      geoEntity.translate(result.geoDiff)
                  else
                    onEntityReady()
    df.promise.fail Meteor.bindEnvironment ->
      # Remove any entities which failed to render to avoid leaving them within Atlas.
      Logger.error('Failed to render entity ' + id)
      _.each addedGeometry, (geometry) -> geometry.remove()
    df.promise

  _renderLot: (id) ->
    entity = Entities.findOne(id)
    lotId = entity.lot
    lot = Lots.findOne(lotId)
    unless lot
      EntityUtils.unrender(id)
      return Q.reject('Rendered geoEntity ' + id + ' does not have an accompanying lot ' + lotId)
    LotUtils.render(lotId)

  _getBlankFeatureArgs: (id) -> @toGeoEntityArgs(id, {vertices: null})

  _setUpEntity: (geoEntity) ->
    unless Meteor.isServer
      # Server doesn't need popups.
      geoEntity.show()
      @_setUpPopup(geoEntity)

  _setUpPopup: (geoEntity) ->
    entity = Entities.getFlattened(AtlasIdMap.getAppId(geoEntity.getId()))
    typology = Typologies.findOne(entity.typology)
    typologyClassId = SchemaUtils.getParameterValue(entity, 'general.class')
    typologyClass = Typologies.Classes[typologyClassId]
    subclass = SchemaUtils.getParameterValue(entity, 'general.subclass')
    AtlasManager.getAtlas().then (atlas) ->
      atlas.publish 'popup/onSelection',
        entity: geoEntity
        content: ->
          '<div class="typology-name">' + typology.name + '</div>'
        title: ->
          title = ''
          _.each ['name'], (attr) ->
            value = (entity[attr] ? '').trim()
            if value
              title += '<div class="' + attr + '">' + value + '</div>'
          title
        onCreate: (popup) ->
          $popup = $(popup.getDom())
          $('.title', $popup).css('color', typologyClass.color)

  renderAll: (args) ->
    args ?= {}
    renderDfs = []
    projectId = args.projectId ? Projects.getCurrentId()
    models = Entities.findByProject(projectId).fetch()
    _.each models, (model) => renderDfs.push @render(model._id)
    Q.all(renderDfs)

  # Bulk rendering is not yet supported, so we simply render everything individually.
  _renderBulk: (args) -> @renderAll(args)

  _getZoomableEntities: ->
    ids = []
    _.each [Entities.findByProject(), Lots.findByProject()], (cursor) ->
      cursor.forEach (doc) -> ids.push doc._id
    ids

  _getEntitiesForJson: (args) ->
    # Include Lots in the entities for JSON export.
    projectId = args.projectId
    # Include Lots in the entities for JSON export.
    entities = Entities.findByProject(projectId).fetch()
    lots = Lots.findByProject(projectId).fetch()
    _.union(entities, lots)

  _renderEntitiesBeforeJson: (args) ->
    df = Q.defer()
    renderPromise = Q.all [LotUtils.renderAll(projectId: args.projectId), @renderAll(args)]
    renderPromise.fail(df.reject)
    renderPromise.then (results) ->
      requirejs [
        'atlas/model/Collection'
        'atlas/model/Feature'
      ], (Collection, Feature) ->
        lotEntities = results[0]
        _.each lotEntities, (lotEntity) ->
          # Remove heights which will cause ACS to render the lots as extrusions.
          lotEntity.setHeight(0)
        geoEntities = results[1]
        Logger.debug('_renderEntitiesBeforeJson', geoEntities.length)
        _.each geoEntities, (geoEntity) ->
          if geoEntity instanceof Feature
            form = geoEntity.getForm(Feature.DisplayMode.FOOTPRINT)
            if form instanceof Collection
              Logger.debug('Found a collection as a footprint', form.getId(), geoEntity.getId())
              featureId = geoEntity.getId()
              # Remove the form so it's not deleted with the feature.
              geoEntity.removeForm(Feature.DisplayMode.FOOTPRINT)
              geoEntity.remove()
              collection = AtlasManager.createCollection featureId,
                  {entities: [form.getId()]}
        df.resolve()
    df.promise

  _unrenderEntitiesBeforeJson: (args) ->
    unrenderPromises = []
    if Meteor.isServer
      _.each args.ids, (id) -> unrenderPromises.push AtlasManager.unrenderEntity(id)
    unrenderPromises
