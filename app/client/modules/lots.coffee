_renderQueue = null
resetRenderQueue = -> _renderQueue = new DeferredQueueMap()

Meteor.startup -> resetRenderQueue()

@LotUtils =

# Handles a assets/synthesize response to create lots.
  fromAsset: (args) ->
    existingDf = Q.defer()
    # If lots already exist in the project, ask the user if they should be removed first.
    existingLots = Lots.findByProject().fetch()
    if existingLots.length > 0
      result = window.confirm('Are you sure you want to replace the existing Lots in the project?')
      if result
        removeDfs = _.map existingLots, (lot) ->
          removeDf = Q.defer()
          Lots.remove lot._id, (err, result) ->
            if err then removeDf.reject(err) else removeDf.resolve(result)
          removeDf.promise
        Q.all(removeDfs).then(existingDf.resolve, existingDf.reject)
      else
        existingDf.reject('Lot creation cancelled')
    else
      existingDf.resolve()

    createDf = Q.defer()
    existingDf.promise.then(
      ->
        Meteor.call 'assets/c3ml/download', args.c3mlId, (err, c3mls) ->
          if err
            console.error(err)
            createDf.reject(err)
            return
          Meteor.call 'assets/metaData/download', args.metaDataId, (err, metaData) ->
            if err
              console.error(err)
              createDf.reject(err)
              return
            Meteor.call 'assets/parameters', args.assetId, (err, params) ->
              if err
                console.error(err)
                createDf.reject(err)
                return
              _.extend(args, {c3mls: c3mls, metaData: metaData, params: params})
              LotUtils._fromAsset(args).then(createDf.resolve, createDf.reject)
      createDf.reject
    )
    createDf.promise

  _fromAsset: (args) ->
    df = Q.defer()
    lotDfs = []
    c3mls = args.c3mls
    metaData = args.metaData
    params = args.params
    polygonC3mls = []
    _.each c3mls, (c3ml) ->
      if c3ml.type == 'polygon'
        polygonC3mls.push(c3ml)
    _.each polygonC3mls, (c3ml, i) ->
      entityId = c3ml.id
      entityParams = params[entityId] ? {}
      lotId = entityParams.propid
      # If the ID is a float value, remove the decimals.
      idIsNumber = Strings.isNumber(lotId)
      if idIsNumber
        lotId = parseFloat(lotId).toString().replace(/\.\d+$/, '')
      # Ignore lots with no geometry.
      if c3ml.coordinates.length == 0
        return
      lotDf = Q.defer()
      lotDfs.push(lotDf.promise)
      WKT.fromC3ml(c3ml).then (wkt) ->
        name = lotId ? 'Lot #' + (i + 1)
        classId = Typologies.getClassByName(entityParams.landuse)
        develop = Booleans.parse(entityParams.develop ? entityParams.redev ? true)
        height = entityParams.height ? c3ml.height
        lot =
          name: name
          project: Projects.getCurrentId()
          parameters:
            general:
              class: classId
              develop: develop
            space:
              geom_2d: wkt
              height: height
        # Validator needs both entity and class set together.
          entity: null
        Lots.insert lot, (err, insertId) ->
          if err
            lotDf.reject(err)
          else
            lotDf.resolve(insertId)
    Q.all(lotDfs).then(
      ->
        projectId = Projects.getCurrentId()
        # If the project doesn't have lat, lng location, set it as that found in this file.
        location = Projects.getLocationCoords(projectId)
        if location.latitude? && location.longitude?
          df.resolve()
        else
          assetPosition = metaData.lookAt?.position
          if assetPosition?
            console.debug 'Setting project location', assetPosition
            Projects.setLocationCoords(projectId,
              {longitude: assetPosition.x, latitude: assetPosition.y}).then(df.resolve, df.reject)
          else
            df.resolve()
      df.reject
    )
    df.promise

  toGeoEntityArgs: (id) ->
    AtlasConverter.getInstance().then (converter) =>
      lot = Lots.findOne(id)
      className = Lots.getParameter(lot, 'general.class')
      isForDevelopment = Lots.getParameter(lot, 'general.develop')
      typologyClass = Typologies.classes[className]
      # Reduce saturation of non-develop lots. Ensure full saturation for develop lots.
      if typologyClass
        color = tinycolor(typologyClass.color).toHsv()
        color.s = if isForDevelopment then 1 else 0.5
        color = tinycolor(color)
      else
        color = tinycolor('#ccc')
      borderColor = tinycolor.darken(color, 40)
      space = lot.parameters.space
      displayMode = @getDisplayMode(id)
      converter.toGeoEntityArgs
        id: id
        vertices: space.geom_2d
        height: space.height
        displayMode: displayMode
        color: color.toHexString()
        borderColor: borderColor.toHexString()

  getDisplayMode: (id) ->
    lot = Lots.findOne(id)
    displayMode = Session.get('lotDisplayMode')
    if displayMode == '_nonDevExtrusion'
      isForDevelopment = Lots.getParameter(lot, 'general.develop')
      if isForDevelopment then 'footprint' else 'extrusion'
    else
      displayMode

# TODO(aramk) Abstract this rendering for Entities as well.
# TODO(aramk) This class has grown too generic - refactor.
  
  render: (id) -> _renderQueue.add(id, => @_render(id))

  _render: (id) ->
    df = Q.defer()
    entity = AtlasManager.getEntity(id)
    if entity
      AtlasManager.showEntity(id)
      df.resolve(entity)
    else
      @toGeoEntityArgs(id).then (entityArgs) ->
        entity = AtlasManager.renderEntity(entityArgs)
        df.resolve(entity)
    df.promise

  renderAll: ->
    lotRenderDfs = []
    lots = Lots.findByProject()
    _.each lots.fetch(), (lot) => lotRenderDfs.push(@render(lot._id))
    Q.all(lotRenderDfs)

  renderAllAndZoom: ->
    lots = Lots.findByProject()
    AtlasManager.zoomToProject()
    # If lots exist, zoom into them.
    if lots.count() != 0
      @renderAll().then -> AtlasManager.zoomToProjectEntities()

  # Find all unallocated development lots and allocate appropriate typologies for them.
  autoAllocate: ->
    console.debug 'Automatically allocating typologies to lots...'
    dfs = []
    typologyMap = Typologies.getClassMap()
    typologies = Typologies.findByProject().fetch()
    _.each Lots.findAvailable(), (lot) ->
      typologyClass = Lots.getParameter(lot, 'general.class')
      if typologyClass?
        classTypologies = typologyMap[typologyClass] ? []
      else
        # Allocate to any typology
        classTypologies = typologies
      unless classTypologies.length > 0
        console.warn 'Could not find suitable typology for lot', lot
        return
      typology = Arrays.getRandomItem(classTypologies)
      console.debug 'Allocating typology', typology, 'to lot', lot
      entityDf = Lots.createEntity(lot._id, typology._id)
      dfs.push(entityDf)
    Q.all(dfs).then -> console.debug 'Successfully allocated', dfs.length, 'lots'

  amalgamate: (ids) ->
    df = Q.defer()
    if ids.length < 2
      throw new Error('At least two lots are needed to amalgamate.')
    lots = Lots.find({_id: {$in: ids}}).fetch()
    someHaveEntities = _.some lots, (lot) -> lot.entity?
    if someHaveEntities
      throw new Error('Cannot amalgamate Lots which have Entities.')
    require ['Polygon'], (Polygon) =>
      WKT.getWKT (wkt) =>
        polygons = []
        _.each lots, (lot) ->
          geom_2d = Lots.getParameter(lot, 'space.geom_2d')
          vertices = wkt.verticesFromWKT(geom_2d)[0]
          polygon = new Polygon(vertices, {
            sortPoints: false, smoothPoints: false, removeDuplicatePoints: true})
          unless polygons.length == 0
            # Each Lot must be touching at least one other Lot.
            someTouching = _.some polygons, (otherPolygon) -> polygon.intersects(otherPolygon)
            unless someTouching
              throw new Error('Lots must be contiguous to amalgamate.')
          polygons.push(polygon)
        combinedPolygon = polygons.shift()
        _.each polygons, (polygon) ->
          combinedPolygon = combinedPolygon.union(polygon).concaveHull()
        combinedLot = Lots.findOne(ids[0])
        delete combinedLot._id
        combinedVertices = combinedPolygon.getPoints()
        combinedWkt = wkt.wktFromVertices(combinedVertices)
        combinedLot.parameters.space.geom_2d = combinedWkt
        console.log 'Inserting combined lot...', combinedLot
        Lots.insert combinedLot, (err, result) =>
          console.log 'Inserted combined lot', err, result
          if err
            df.reject(err)
          else
            # Remove original lots after amalgamation.
            @removeByIds(ids).then(df.resolve, df.reject)
    df.promise

  removeByIds: (ids) ->
    console.log 'removeByIds', ids
    dfs = []
    _.each ids, (id) ->
      df = Q.defer()
      dfs.push(df.promise)
      Lots.remove id, (err, result) ->
        if err then df.reject(err) else df.resolve(result)
    Q.all(dfs)

  beforeAtlasUnload: -> resetRenderQueue()

