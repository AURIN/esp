@LotUtils =

# Handles a assets/synthesize response to create lots.
  fromAsset: (args) ->
    df = Q.defer()
    Meteor.call 'assets/c3ml/download', args.c3mlId, (err, c3mls) ->
      if err
        console.error(err)
        df.reject(err)
        return
      Meteor.call 'assets/metaData/download', args.metaDataId, (err, metaData) ->
        if err
          console.error(err)
          df.reject(err)
          return
        Meteor.call 'assets/parameters', args.assetId, (err, params) ->
          if err
            console.error(err)
            df.reject(err)
            return
          _.extend(args, {c3mls: c3mls, metaData: metaData, params: params})
          LotUtils._fromAsset(args).then(df.resolve, df.reject)
    df.promise

  _fromAsset: (args) ->
    df = Q.defer()
    c3mls = args.c3mls
    metaData = args.metaData
    params = args.params
    lotIds = []
    doneCalls = 0
    polygonC3mls = []
    done = (id) ->
      lotIds.push(id)
      doneCalls++
      console.debug('done', id, doneCalls, c3mls.length)
      if doneCalls == polygonC3mls.length
        projectId = Projects.getCurrentId()
        # If the project doesn't have lat, lng location, set it as that found in this file.
        location = Projects.getLocationCoords(projectId)
        unless location.latitude? && location.longitude?
          assetPosition = metaData.lookAt?.position
          if assetPosition?
            console.debug 'Setting project location', assetPosition
            Projects.setLocationCoords(projectId,
              {longitude: assetPosition.x, latitude: assetPosition.y})
        df.resolve(lotIds)
    _.each c3mls, (c3ml) ->
      if c3ml.type == 'polygon'
        polygonC3mls.push(c3ml)
    _.each polygonC3mls, (c3ml, i) ->
      entityId = c3ml.id
      entityParams = params[entityId] ? {}
      lotId = entityParams.id
      # If the ID is a float value, remove the decimals.
      idIsNumber = !/[^\d\.]/g.test(lotId)
      if idIsNumber
        lotId = lotId.replace(/\.\d+$/, '')
      coords = c3ml.coordinates
      name = lotId ? 'Lot #' + (i + 1)
      # C3ml coordinates are in (longitude, latitude), but WKT is the reverse.
      WKT.fromVertices coords, (wkt) ->
        lot =
          name: name
          project: Projects.getCurrentId()
          parameters:
            general:
              class: Typologies.resolveClassId(entityParams.landuse)
              dev: Booleans.parse(entityParams.redev ? true)
            space:
              geom: wkt
              height: c3ml.height
        id = Lots.insert(lot)
        console.debug('lot', id, lot)
        done(id)
    df.promise

  toGeoEntityArgs: (id) ->
    AtlasConverter.getInstance().then (converter) ->
      lot = Lots.findOne(id)
      space = lot.parameters.space
      converter.toGeoEntityArgs
        id: id
        vertices: space.geom
        height: space.height
        color: '#8ae200'
        borderColor: '#000'
