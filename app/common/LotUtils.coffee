@LotUtils =

  ##################################################################################################
  # IMPORTING
  ##################################################################################################

  # Handles a assets/synthesize response to create lots.
  fromAsset: (args) ->
    c3mls = args.c3mls
    projectId = args.projectId ? Projects.getCurrentId()
    isLayer = args.isLayer
    if isLayer
      return LayerUtils.fromAsset(args)

    # If lots already exist in the project, remove them after importing.
    existingLots = Lots.findByProject(projectId).fetch()
    
    createDf = Q.defer()
    LotUtils._fromAsset(args).then(
      Meteor.bindEnvironment ->
        if existingLots.length == 0
          createDf.resolve()
          return
        removeDfs = _.map existingLots, (lot) ->
          removeDf = Q.defer()
          Lots.remove lot._id, (err, result) ->
            if err then removeDf.reject(err) else removeDf.resolve(result)
          removeDf.promise
        Q.all(removeDfs).then(
          createDf.resolve
          Meteor.bindEnvironment (err) ->
            Logger.error('Could not remove all existing lots', err)
            createDf.resolve()
        )
      createDf.reject
    )
    createDf.promise

  _fromAsset: (args) ->
    modelDfs = []
    c3mls = args.c3mls
    if c3mls.length > 2000
      return Q.reject('Cannot import assets containing more than 2000 objects.')

    df = Q.defer()
    projectId = args.projectId ? Projects.getCurrentId()
    polygonC3mls = []
    _.each c3mls, (c3ml) ->
      if AtlasConverter.sanitizeType(c3ml.type) == 'polygon'
        polygonC3mls.push(c3ml)
    _.each polygonC3mls, (c3ml, i) ->
      entityId = c3ml.id
      entityParams = c3ml.properties ? {}
      lotId = entityParams.propid
      # If the ID is a float value, remove the decimals.
      idIsNumber = Strings.isNumber(lotId)
      if idIsNumber
        lotId = parseFloat(lotId).toString().replace(/\.\d+$/, '')
      # Ignore lots with no geometry.
      if c3ml.coordinates.length == 0
        return
      lotDf = Q.defer()
      modelDfs.push(lotDf.promise)
      WKT.fromC3ml(c3ml).then Meteor.bindEnvironment (wkt) ->
        name = lotId ? 'Lot #' + (i + 1)
        classId = Typologies.getClassByName(entityParams.landuse)
        develop = Booleans.parse(entityParams.develop ? entityParams.redev ? true)
        height = entityParams.height ? c3ml.height
        lot =
          name: name
          project: projectId
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
    modelPromises = Q.all(modelDfs)
    modelPromises.fail(df.reject)
    modelPromises.then Meteor.bindEnvironment ->
      requirejs ['atlas/model/GeoPoint'], Meteor.bindEnvironment (GeoPoint) ->
        importCount = modelDfs.length
        resolve = -> df.resolve(importCount)
        Logger.info 'Imported ' + importCount + ' entities'
        # If the project doesn't have lat, lng location, set it as that found in this file.
        location = Projects.getLocationCoords(projectId)
        if location.latitude? && location.longitude?
          resolve()
        else
          assetPosition = null
          _.some c3mls, (c3ml) ->
            position = c3ml.coordinates[0] ? c3ml.geoLocation
            if position
              assetPosition = new GeoPoint(position)
          if assetPosition?
            Logger.info 'Setting project location', assetPosition
            Projects.setLocationCoords(projectId, assetPosition).then(resolve, df.reject)
          else
            resolve()
    df.promise

  ##################################################################################################
  # RENDERING
  ##################################################################################################

  toGeoEntityArgs: (id) ->
    df = Q.defer()
    @converterPromise.then Meteor.bindEnvironment (converter) =>
      df.resolve @_toGeoEntityArgs(id, converter)
    df.promise

  _toGeoEntityArgs: (id, converter) ->
    lot = Lots.findOne(id)
    typologyClass = SchemaUtils.getParameterValue(lot, 'general.class')
    isForDevelopment = SchemaUtils.getParameterValue(lot, 'general.develop')
    typologyClassArgs = Typologies.Classes[typologyClass]
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
          color = tinycolor(color).lighten(25)
    color = tinycolor(color)
    borderColor = tinycolor(color.toHexString()).darken(40)
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
          color1: color.toHexString()
          color2: color.darken(5).toHexString()
        borderColor: borderColor.toHexString()
    else
      args.style =
        fillColor: color.toHexString()
        borderColor: borderColor.toHexString()
    converter.toGeoEntityArgs(args)

  getDisplayMode: (id) ->
    lot = Lots.findOne(id)
    # If Session is not available (on the server), use the default value.
    displayMode = Session?.get('lotDisplayMode') ? 'footprint'
    if displayMode == '_nonDevExtrusion'
      isForDevelopment = SchemaUtils.getParameterValue(lot, 'general.develop')
      if isForDevelopment then 'footprint' else 'extrusion'
    else
      displayMode

  # TODO(aramk) Abstract this rendering for Entities as well.
  # TODO(aramk) This class has grown too generic - refactor.
    
  render: (id) -> @renderQueue.add id, => @_render(id)

  _render: (id) ->
    df = Q.defer()
    entity = AtlasManager.getEntity(id)
    if entity
      AtlasManager.showEntity(id)
      df.resolve(entity)
    else
      @toGeoEntityArgs(id).then Meteor.bindEnvironment (entityArgs) ->
        entity = AtlasManager.renderEntity(entityArgs)
        df.resolve(entity)
    df.promise

  unrender: (id) -> @renderQueue.add id, ->
    df = Q.defer()
    AtlasManager.unrenderEntity(id)
    df.resolve()
    df.promise

  renderAll: (args) -> @renderQueue.add 'bulk', => @_renderBulk(args)

  _renderBulk: (args)  ->
    args ?= {}
    df = Q.defer()
    ids = args.ids
    if ids
      lots = []
      _.each ids, (id) -> lots.push Lots.findOne(id)
    else
      projectId = args.projectId ? Projects.getCurrentId()
      lots = Lots.findByProject(projectId).fetch()
    @converterPromise.then Meteor.bindEnvironment (converter) => 
      geoEntities = []
      _.each lots, (lot) =>
        id = lot._id
        geoEntity = AtlasManager.getEntity(id)
        unless geoEntity
          geoEntityArgs = @_toGeoEntityArgs(id, converter)
          geoEntity = AtlasManager.renderEntity(geoEntityArgs)
        geoEntities.push geoEntity
      df.resolve(geoEntities)
    df.promise

  renderAllAndZoom: -> @renderAll().then => @_zoomToEntities()

  whenRenderingComplete: -> @renderQueue.waitForAll()

  _zoomToEntities: ->
    ids = _.map Lots.findByProject().fetch(), (entity) -> entity._id
    AtlasManager.zoomToEntities(ids)

  getSelectedLots: -> _.filter AtlasManager.getSelectedFeatureIds(), (id) -> Lots.findOne(id)

  ##################################################################################################
  # SERVICES
  ##################################################################################################

  setUp: ->
    # Auto-align when adding new lots or adding/replacing entities on lots.
    return if @isSetUp

    autoAlignEntity = Meteor.bindEnvironment (entity) ->
      azimuth = SchemaUtils.getParameterValue(entity, 'orientation.azimuth')
      LotUtils.autoAlign([entity.lot]) unless azimuth?

    if Meteor.isServer

      Lots.after.insert Meteor.bindEnvironment (userId, doc) ->
        entityId = doc.entity
        if entityId
          autoAlignEntity(Entities.findOne(entityId))

      Lots.after.update Meteor.bindEnvironment (userId, newDoc) ->
        oldDoc = @previous
        entityId = newDoc.entity
        # TODO(aramk) Using Meteor.bindEnvironment means the context is not correctly bound to this
        # callback.
        if entityId && (!oldDoc || oldDoc.entity != entityId)
          autoAlignEntity(Entities.findOne(entityId))

    converterDf = Q.defer()
    @converterPromise = converterDf.promise
    AtlasConverter.getInstance().then Meteor.bindEnvironment (converter) ->
      converterDf.resolve(converter)

    @reset()
    @isSetUp = true

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

      lotDf = Q.defer()
      dfs.push(lotDf.promise)

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

      Q.all(validateDfs).then Meteor.bindEnvironment (results) ->
        typologies = _.filter results, (result) -> result?
        if typologies.length > 0
          typology = Arrays.getRandomItem(typologies)
          console.debug 'Allocating typology', typology, 'to lot', lot
          Lots.createEntity({
            lotId: lot._id, typologyId: typology._id, allowReplace: args.replace,
            allowNonDevelopment: args.allowNonDevelopment
          }).then(lotDf.resolve, lotDf.reject)
        else
          lotDf.reject('No suitable typologies could be found for lot ' + lot._id)
    df = Q.defer()
    Q.all(dfs).then(
      (entityIds) ->
        console.debug 'Successfully allocated', dfs.length, 'lots'
        LotUtils.autoAlign(args.lotIds).fin -> df.resolve(args.lotIds)
      df.reject
    )
    df.promise

  amalgamate: (ids) ->
    df = Q.defer()
    if ids.length < 2
      return Q.reject('At least two Lots are needed to amalgamate.')
    lots = Lots.find({_id: {$in: ids}}).fetch()
    someHaveEntities = _.some lots, (lot) -> lot.entity?
    if someHaveEntities
      return Q.reject('Cannot amalgamate Lots which have Entities.')
    requirejs ['subdiv/Polygon'], (Polygon) =>
      WKT.getWKT Meteor.bindEnvironment (wkt) =>
        polygons = []
        # Used for globalising and localising points.
        referencePoint = null
        success = _.all lots, (lot) ->
          geom_2d = SchemaUtils.getParameterValue(lot, 'space.geom_2d')
          vertices = wkt.verticesFromWKT(geom_2d)
          polygon = new Polygon(vertices)
          referencePoint = polygon.getPoints()[0] unless referencePoint
          polygon.localizePoints(referencePoint)
          unless polygons.length == 0
            # Each Lot must be touching at least one other Lot.
            someTouching = _.some polygons, (otherPolygon) -> polygon.intersects(otherPolygon)
            unless someTouching
              df.reject('Lots must be contiguous to amalgamate.')
              return false
          polygons.push(polygon)
          true
        return unless success
        combinedPolygon = polygons.shift()
        success = _.all polygons, (polygon) ->
          nextCombination = combinedPolygon.union(polygon,
              {sortPoints: false, smoothPoints: false})
          if nextCombination.length != 1
            df.reject('Amalgamation failed: ' + nextCombination.length + ' polygons produced')
            return false
          combinedPolygon = nextCombination[0]
          true
        return unless success
        combinedLot = Lots.findOne(ids[0])
        delete combinedLot._id
        combinedPolygon.globalizePoints(referencePoint)
        combinedVertices = combinedPolygon.getPoints()
        combinedWkt = wkt.wktFromVertices(combinedVertices)
        combinedLot.parameters.space.geom_2d = combinedWkt
        Logger.info 'Inserting combined lot...', combinedLot
        Lots.insert combinedLot, (err, result) =>
          Logger.info 'Inserted combined lot', err, result
          if err
            df.reject(err)
          else
            # Remove original lots after amalgamation.
            @removeByIds(ids).then(df.resolve, df.reject)
    df.promise

  subdivide: (ids, linePoints) ->
    if ids.length == 0
      return Q.reject('At least one Lot is needed to subdivide.')
    lots = Lots.find({_id: {$in: ids}}).fetch()
    someHaveEntities = _.some lots, (lot) -> lot.entity?
    if someHaveEntities
      return Q.reject('Cannot subdivide Lots which have Entities.')
    df = Q.defer()
    requirejs ['subdiv/Polygon', 'subdiv/Line'], (Polygon, Line) =>
      WKT.getWKT Meteor.bindEnvironment (wkt) =>
        polygons = []
        # Used for globalising and localising points.
        referencePoint = null
        _.each lots, (lot) ->
          geom_2d = SchemaUtils.getParameterValue(lot, 'space.geom_2d')
          vertices = wkt.verticesFromWKT(geom_2d)
          polygon = new Polygon(vertices, {sortPoints: false})
          polygon.id = lot._id
          referencePoint = polygon.getPoints()[0] unless referencePoint
          polygon.localizePoints(referencePoint)
          polygons.push(polygon)
        lineVertices = _.map linePoints, (point) -> point.toVertex()
        line = new Line(lineVertices)
        line.localizePoints(referencePoint)
        subdividedMap = {}
        allSubdividedPolygons = []
        _.each polygons, (polygon) ->
          subdividedPolygons = subdividedMap[polygon.id] = []
          diffPolygons = polygon.difference(line)
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
    Logger.info('Auto-aligning lots...', ids)
    df = Q.defer()
    alignLots = []
    _.each ids, (id) ->
      lot = Lots.findOne(id)
      alignLots.push(lot) if lot.entity
    projectId = Lots.findOne(ids[0])?.project
    unless alignLots.length > 0
      df.reject('No lots with entities found for auto-alignment.')
      return df.promise
    WKT.getWKT Meteor.bindEnvironment (wkt) ->
      requirejs [
        'atlas/model/Vertex'
        'subdiv/AlignmentCalculator'
        'subdiv/Polygon'
        'subdiv/util/GeographicUtil'
      ], Meteor.bindEnvironment (Vertex, AlignmentCalculator, Polygon, GeographicUtil) ->
        polyMap = {}
        polygonPromises = []
        # Construct polygons for all lots and use them to determine the orientation of the street
        # for the given lots.
        Lots.findByProject(projectId).forEach (lot) ->
          geom_2d = SchemaUtils.getParameterValue(lot, 'space.geom_2d')
          polygonPromises.push GeometryUtils.getWktOrC3mls(geom_2d).then (wktOrC3mls) ->
            try
              if Types.isString(wktOrC3mls)
                vertices = wkt.verticesFromWKT(geom_2d)
              else
                vertices = _.find wktOrC3mls, (c3ml) ->
                  coords = c3ml.coordinates
                  if coords then _.map coords, (coord) -> new Vertex(coord)
                unless vertices
                  Logger.warn('Ignoring c3mls - could not find any vertices')
                  return null
              polygon = new Polygon(vertices).smoothPoints()
              GeographicUtil.localizePointGeometry(polygon)
              polyMap[lot._id] = polygon
              return polygon
            catch e
              Logger.error('Failed to localise polygon during auto align', e, e.stack)
              return null

        Q.all(polygonPromises).then Meteor.bindEnvironment (polygons) ->
          polygons = _.filter polygons, (polygon) -> polygon?
          alignCalc = new AlignmentCalculator(polygons)
          entityDfs = []
          _.each alignLots, (alignLot) ->
            lotId = alignLot._id
            polygon = polyMap[lotId]
            angle = alignCalc.getStreetInfo(polygon)?.angle
            return unless angle?
            # 0 degrees is north-facing according to typologies. SubDiv assumes 0 degrees to be
            # east. We must subtract 90 degrees to convert from SubDiv to the typology's 0 degree.
            # The front of the typology is assumed to be south, so we must add 180 degrees. Hence,
            # we have a net change of 90 degrees.
            angle += 90
            entityDf = Q.defer()
            entityDfs.push(entityDf.promise)
            # Convert the angle from counter-clockwise to clockwise.
            angle = 360 - angle
            Entities.update alignLot.entity,
              {$set: 'parameters.orientation.azimuth': angle}, (err, result) ->
                if err then entityDf.reject(err) else entityDf.resolve(lotId)
          df.resolve Q.all(entityDfs).then (lotIds) ->
            Logger.info('Auto-aligned lots', lotIds)

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
      df.then (area) ->
        if args.indexByArea
          areaModels = fpas[area] ?= []
          areaModels.push(lot._id)
        else
          fpas[lot._id] = area
    Q.all(areaDfs).then -> fpas

  removeByIds: (ids) ->
    dfs = []
    _.each ids, (id) ->
      df = Q.defer()
      dfs.push(df.promise)
      Lots.remove id, (err, result) ->
        if err then df.reject(err) else df.resolve(result)
    Q.all(dfs)

  beforeAtlasUnload: -> @reset()

  reset: ->
    @renderQueue = new DeferredQueueMap()

Meteor.startup -> LotUtils.setUp()

if Meteor.isServer
  Meteor.methods
    'lots/from/asset': (args) -> Promises.runSync -> LotUtils.fromAsset(args)
