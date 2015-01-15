_renderQueue = null
resetRenderQueue = -> _renderQueue = new DeferredQueueMap()
evalEngine = null

Meteor.startup ->
  resetRenderQueue()
  evalEngine = new EvaluationEngine(schema: Lots.simpleSchema())

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
      typologyClass = SchemaUtils.getParameterValue(lot, 'general.class')
      isForDevelopment = SchemaUtils.getParameterValue(lot, 'general.develop')
      typologyClassArgs = Typologies.classes[typologyClass]
      # Reduce saturation of non-develop lots. Ensure full saturation for develop lots.
      color = '#ccc'
      if typologyClassArgs
        typology = Typologies.findOne(Entities.findOne(lot.entity)?.typology)
        subclasses = typologyClassArgs.subclasses
        subclass = typology && SchemaUtils.getParameterValue(typology, 'general.subclass')
        color = typologyClassArgs.color ? color
        if subclass &&  Types.isObject(subclasses)
          color = subclasses[subclass]?.color ? color
        unless isForDevelopment
          nonDevColor = typologyClassArgs.nonDevColor
          if nonDevColor
            color = nonDevColor
          else
            color = tinycolor.lighten(color, 25)
      color = tinycolor(color)
      borderColor = tinycolor.darken(color, 40)
      space = lot.parameters.space
      displayMode = @getDisplayMode(id)
      args =
        id: id
        vertices: space.geom_2d
        displayMode: displayMode
      height = space.height
      if height?
        args.height = height
      if typologyClass == 'OPEN_SPACE' && lot.entity?
        # If the lot is an Open Space with an entity, render it with a check pattern to show it
        # has an entity allocated.
        args.style =
          fillMaterial:
            type: 'CheckPattern',
            color1: color.toHexString(),
            color2: tinycolor.darken(color, 5).toHexString()
          borderColor: borderColor.toHexString()
      else
        args.style =
          fillColor: color.toHexString()
          borderColor: borderColor.toHexString()
      converter.toGeoEntityArgs(args)

  getDisplayMode: (id) ->
    lot = Lots.findOne(id)
    displayMode = Session.get('lotDisplayMode')
    if displayMode == '_nonDevExtrusion'
      isForDevelopment = SchemaUtils.getParameterValue(lot, 'general.develop')
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

  unrender: (id) -> _renderQueue.add id, ->
    df = Q.defer()
    AtlasManager.unrenderEntity(id)
    df.resolve()
    df.promise

  renderAll: ->
    lotRenderDfs = []
    lots = Lots.findByProject()
    _.each lots.fetch(), (lot) => lotRenderDfs.push(@render(lot._id))
    Q.all(lotRenderDfs)

  renderAllAndZoom: ->
    @renderAll().then => @_zoomToEntities()

  _zoomToEntities: ->
    ids = _.map Lots.findByProject().fetch(), (entity) -> entity._id
    AtlasManager.zoomToEntities(ids)

  # Allocate a set of typologies to a set of lots.
  # @param {Object} args
  # @param {Array.<String>} lotIds
  # @param {Array.<String>} typologyIds
  # @param {Boolean} allowNonDevelopment - Whether to also allocate lots which are marked for
  #      non-development.
  # @param {Boolean} replace - Whether to replace existing allocations.
  # @returns {Promise}
  autoAllocate: (args) ->
    args = _.extend({
      lotIds: []
      typologyIds: []
      allowNonDevelopment: false
      replace: false
    }, args)
    console.debug 'Automatically allocating typologies to lots...', args
    dfs = []
    lots = _.map args.lotIds, (id) -> Lots.findOne(id)
    typologies = _.map args.typologyIds, (id) -> Typologies.findOne(id)
    typologyMap = Typologies.getClassMap(typologies)
    _.each lots, (lot) ->
      develop = SchemaUtils.getParameterValue(lot, 'general.develop')
      return if !args.allowNonDevelopment && !develop
      return if !args.replace && lot.entity
      
      typologyClass = SchemaUtils.getParameterValue(lot, 'general.class')
      if typologyClass?
        lotTypologies = typologyMap[typologyClass] ? []
      else
        # Allocate to any typology
        lotTypologies = typologies
      unless lotTypologies.length > 0
        console.warn 'Could not find suitable typology for lot', lot
        return
      return unless lotTypologies.length > 0

      entityDf = Q.defer()
      dfs.push(entityDf.promise)

      # Find the area of all possible typologies to prevent placing a typology which does not fit.
      validateDfs = []
      # Ensure lot validation succeeds if we allow non-developable lots to be used.
      if args.allowNonDevelopment
        SchemaUtils.setParameterValue(lot, 'general.develop', true)
      _.each lotTypologies, (typology) ->
        validateDf = Q.defer()
        Lots.validateTypology(lot, typology._id).then(
          (err) -> if err? then validateDf.resolve(null) else validateDf.resolve(typology)
          validateDf.reject
        )
        validateDfs.push(validateDf.promise)

      Q.all(validateDfs).then (results) ->
        typologies = _.filter results, (result) -> result?
        if typologies.length > 0
          typology = Arrays.getRandomItem(typologies)
          console.debug 'Allocating typology', typology, 'to lot', lot
          Lots.createEntity({
            lotId: lot._id, typologyId: typology._id, allowReplace: args.replace,
            allowNonDevelopment: args.allowNonDevelopment
          }).then(entityDf.resolve, entityDf.reject)
        entityDf.resolve()
    Q.all(dfs).then -> console.debug 'Successfully allocated', dfs.length, 'lots'

  amalgamate: (ids) ->
    df = Q.defer()
    if ids.length < 2
      throw new Error('At least two Lots are needed to amalgamate.')
    lots = Lots.find({_id: {$in: ids}}).fetch()
    someHaveEntities = _.some lots, (lot) -> lot.entity?
    if someHaveEntities
      throw new Error('Cannot amalgamate Lots which have Entities.')
    require ['subdiv/Polygon'], (Polygon) =>
      WKT.getWKT (wkt) =>
        polygons = []
        # Used for globalising and localising points.
        referencePoint = null
        _.each lots, (lot) ->
          geom_2d = SchemaUtils.getParameterValue(lot, 'space.geom_2d')
          vertices = wkt.verticesFromWKT(geom_2d)[0]
          polygon = new Polygon(vertices)
          referencePoint = polygon.getPoints()[0] unless referencePoint
          polygon.localizePoints(referencePoint)
          unless polygons.length == 0
            # Each Lot must be touching at least one other Lot.
            someTouching = _.some polygons, (otherPolygon) -> polygon.intersects(otherPolygon)
            unless someTouching
              throw new Error('Lots must be contiguous to amalgamate.')
          polygons.push(polygon)
        combinedPolygon = polygons.shift()
        _.each polygons, (polygon) ->
          combinedPolygon = combinedPolygon.union(polygon, {sortPoints: false, smoothPoints: false})[0]
        combinedLot = Lots.findOne(ids[0])
        delete combinedLot._id
        combinedPolygon.globalizePoints(referencePoint)
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

  subdivide: (ids, linePoints) ->
    df = Q.defer()
    if ids.length == 0
      throw new Error('At least one Lot is needed to subdivide.')
    lots = Lots.find({_id: {$in: ids}}).fetch()
    someHaveEntities = _.some lots, (lot) -> lot.entity?
    if someHaveEntities
      throw new Error('Cannot subdivide Lots which have Entities.')
    require ['subdiv/Polygon', 'subdiv/Line'], (Polygon, Line) =>
      WKT.getWKT (wkt) =>
        polygons = []
        # Used for globalising and localising points.
        referencePoint = null
        _.each lots, (lot) ->
          geom_2d = SchemaUtils.getParameterValue(lot, 'space.geom_2d')
          vertices = wkt.verticesFromWKT(geom_2d)[0]
          polygon = new Polygon(vertices, {sortPoints: false})
          polygon.id = lot._id
          referencePoint = polygon.getPoints()[0] unless referencePoint
          polygon.localizePoints(referencePoint)
          polygons.push(polygon)
        lineVertices = _.map linePoints, (point) -> point.toVertex()
        line = new Line(lineVertices)
        line.localizePoints(referencePoint)
        console.log('polygons', polygons)
        console.log('line', line)
        subdividedMap = {}
        allSubdividedPolygons = []
        _.each polygons, (polygon) ->
          subdividedPolygons = subdividedMap[polygon.id] = []
          diffPolygons = polygon.difference(line)
          console.log('diffPolygons', diffPolygons)
          _.each diffPolygons, (diffPolygon) ->
            # Ensure the subdivided polygons are contained in the original Lot polygon. If we draw a
            # line outside the Lot polygon, it can form a polygon on the outside which we should
            # ignore. We use ovelaps() instead of contains() since the latter requires the geometry
            # to either be absolutely fully contained (not the case) or share a perimeter (which all
            # our polygons do).
            if diffPolygon.overlaps(polygon)
              diffPolygon.globalizePoints(referencePoint)
              subdividedPolygons.push(diffPolygon)
              allSubdividedPolygons.push(diffPolygon)
        if allSubdividedPolygons.length == 0
          df.reject('No resulting polygons after subdivision.')
        else if allSubdividedPolygons.length == polygons.length
          df.reject('Same number of polygons after subdivision.')
        else
          # Create subdivided lots by cloning the original and applying the subdivided geometry.
          insertDfs = []
          _.each subdividedMap, (subdividedPolygons, id) ->
            insertDf = Q.defer()
            insertDfs.push(insertDf.promise)
            lot = Lots.findOne(id)
            delete lot._id
            _.each subdividedPolygons, (polygon) ->
              vertices = polygon.getPoints()
              wktStr = wkt.wktFromVertices(vertices)
              subLot = Setter.clone(lot)
              SchemaUtils.setParameterValue(subLot, 'space.geom_2d', wktStr)
              Lots.insert subLot, (err, result) ->
                if err then insertDf.reject(err) else insertDf.resolve(result)
          Q.all(insertDfs).then(
            =>
              # Remove original lots after subdivision.
              @removeByIds(ids).then(df.resolve, df.reject)
            df.reject
          )
    df.promise

  autoAlign: (ids) ->
    df = Q.defer()
    alignLots = []
    _.each ids, (id) ->
      lot = Lots.findOne(id)
      alignLots.push(lot) if lot.entity
    unless alignLots.length > 0
      df.reject('No lots with entities found for auto-alignment.')
      return df.promise
    WKT.getWKT (wkt) ->
      require [
        'subdiv/AlignmentCalculator',
        'subdiv/Polygon',
        'subdiv/util/GeographicUtil'
      ], (AlignmentCalculator, Polygon, GeographicUtil) ->
        polyMap = {}
        polygons = Lots.findByProject().map (lot) ->
          geom_2d = SchemaUtils.getParameterValue(lot, 'space.geom_2d')
          vertices = wkt.verticesFromWKT(geom_2d)[0]
          polygon = new Polygon(vertices).smoothPoints()
          GeographicUtil.localizePointGeometry(polygon)
          polyMap[lot._id] = polygon
        
        alignCalc = new AlignmentCalculator(polygons)
        entityDfs = []
        _.each alignLots, (alignLot) ->
          polygon = polyMap[alignLot._id]
          angle = alignCalc.getStreetInfo(polygon)?.angle
          return unless angle?
          # 0 degrees is north-facing according to typologies. SubDiv assumes 0 degrees to be east.
          # We must subtract 90 degrees to convert from SubDiv to the typology's 0 degree. The front
          # of the typology is assumed to be south, so we must add 180 degrees. Hence, we have a net
          # change of 90 degrees.
          angle += 90
          entityDf = Q.defer()
          entityDfs.push(entityDf.promise)
          # Convert the angle from counter-clockwise to clockwise.
          angle = 360 - angle
          Entities.update alignLot.entity,
            {$set: 'parameters.orientation.azimuth': angle}, (err, result) ->
              if err then entityDf.reject(err) else entityDf.resolve(result)
        
        Q.all(entityDfs).then(df.resolve, df.reject)
    df.promise
      
  getAreas: (args) ->
    args = _.extend({
      indexByArea: false
    }, args)
    fpas = {}
    areaDfs = []
    Lots.findByProject().forEach (lot) ->
      df = GeometryUtils.getModelArea(lot)
      areaDfs.push(df)
      df.then (results) ->
        if args.indexByArea
          fpas[results.area] ?= results
        else
          fpas[lot._id] = results
    Q.all(areaDfs).then -> fpas

  removeByIds: (ids) ->
    dfs = []
    _.each ids, (id) ->
      df = Q.defer()
      dfs.push(df.promise)
      Lots.remove id, (err, result) ->
        if err then df.reject(err) else df.resolve(result)
    Q.all(dfs)

  beforeAtlasUnload: -> resetRenderQueue()
