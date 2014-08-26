# TODO(aramk) Refactor with LotUtils

@EntityUtils =
  
  toGeoEntityArgs: (id) ->
    AtlasConverter.getInstance().then (converter) ->
      entity = Entities.getFlattened(id)
      typology = Typologies.findOne(entity.typology)
      space = entity.parameters.space
      typologySpace = typology.parameters.space
      displayMode = Session.get('entityDisplayMode')
#      getMesh = ->
#        df = Q.defer()
#        meshFileId = Entities.getParameter(entity, 'space.mesh')
#        unless meshFileId?
#          df.resolve(null)
#        Meteor.call 'files/download/string', meshFileId, (err, data) ->
#          if err
#            df.reject(err)
#          else
#            df.resolve()
#        meshFileId
#        df.promise
      converter.toGeoEntityArgs
        id: id
#        mesh: mesh
        vertices: space.geom ? typologySpace.geom
        height: space.height
        zIndex: 1
        displayMode: displayMode
        color: '#666'
        borderColor: '#000'

  render: (id) ->
    df = Q.defer()
    entity = AtlasManager.getEntity(id)
    if entity
      AtlasManager.showEntity(id)
      df.resolve(entity)
    else
      getMesh = ->
        meshDf = Q.defer()
        entity = Entities.getFlattened(id)
        meshFileId = Entities.getParameter(entity, 'space.mesh')
        unless meshFileId?
          meshDf.reject('No mesh for entity ' + id)
        Meteor.call 'files/download/json', meshFileId, (err, data) ->
          console.log('download', arguments)
          if err
            meshDf.reject(err)
          else
            meshDf.resolve(data)
        meshDf.promise

      @toGeoEntityArgs(id).then (entityArgs) ->
        entity = AtlasManager.renderEntity(entityArgs)
        # If the entity was rendered using the Typology geometry, centre it based on the Lot.
        lot = Lots.findByEntity(id)
        unless lot
          AtlasManager.unrenderEntity(id)
          throw new Error('Rendered entity does not have an accompanying lot.')
        LotUtils.render(lot._id).then (lotEntity) ->
          lotCentroid = lotEntity.getCentroid()
          centroidDiff = lotCentroid.subtract(entity.getCentroid())
          entity.translate(centroidDiff)
          df.resolve(entity)

          _meshDf = getMesh()
          _meshDf.then (result) ->
            if result
              console.log('c3mls', result.c3mls)
              try
                c3mlEntities = AtlasManager.renderEntities(result.c3mls)
              catch e
                console.error(e)
              console.log('c3mlEntities', c3mlEntities)
              _.each c3mlEntities, (c3mlEntity) ->
                if c3mlEntity.getForm
                  c3mlEntity = c3mlEntity.getForm()
                  unless c3mlEntity
                    return
                # TODO(aramk) Meshes still don't have centroid support so use geolocation for now.
                if c3mlEntity.getGeoLocation
                  c3mlCentroid = c3mlEntity.getGeoLocation()
                else
                  c3mlCentroid = c3mlEntity.getCentroid()
                unless c3mlCentroid
                  return
                console.log('c3mlCentroid', c3mlCentroid)
                c3mlCentroidDiff = lotCentroid.subtract(c3mlCentroid)
                c3mlEntity.translate(c3mlCentroidDiff)

          _meshDf.fail -> console.error(arguments)

    df.promise
