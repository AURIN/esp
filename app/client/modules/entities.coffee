# TODO(aramk) Refactor with LotUtils

@EntityUtils =
  
  toGeoEntityArgs: (id) ->
    AtlasConverter.getInstance().then (converter) ->
      entity = Entities.findOne(id)
      typology = Typologies.findOne(entity.typology)
      space = entity.parameters.space
      typologySpace = typology.parameters.space
      displayMode = Session.get('entityDisplayMode')
      converter.toGeoEntityArgs
        id: id
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
      @toGeoEntityArgs(id).then (entityArgs) ->
        entity = AtlasManager.renderEntity(entityArgs)
        # If the entity was rendered using the Typology geometry, centre it based on the Lot.
        lot = Lots.findByEntity(id)
        unless lot
          throw new Error('Rendered entity does not have an accompanying lot.')
        LotUtils.render(lot._id).then (lotEntity) ->
          centroidDiff = lotEntity.getCentroid().subtract(entity.getCentroid())
          entity.translate(centroidDiff)
          df.resolve(entity)
        # TODO(aramk) Lot assumed to be rendered here
    df.promise
