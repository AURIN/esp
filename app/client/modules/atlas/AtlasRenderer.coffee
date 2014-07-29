# TODO(aramk) Deprecated.

class @AtlasRenderer

  assets: null
  entities: null
  atlas: null
  converter: null

  startup: (args) ->
    args = _.extend({}, args)
    @atlas = args.atlas
    @assets = {}
    @entities = {}
    @converter = new AtlasConverter()
    _.each(args.assets, @addAsset.bind(this))

  # ADDING

  addAsset: (asset) ->
    id = asset.id
    if !id
      id = asset.id = asset.name

    if @assets[id] != undefined
      throw new Error('Asset already added: ' + id)

    @assets[id] = asset
    entities = asset.entities
    addedEntities = []
    entities && _.each(entities, (entity, i) =>
      if typeof entity == 'string' then entity = asset.entities[i] = {vertices: entity}
      entity.id = id + '-' + (i + 1)
      entity._asset = asset
      @addEntity(entity)
      addedEntities.push(entity)
    )
    asset._origEntities = asset.entities
    asset.entities = addedEntities

  addEntity: (entity) ->
    @entities[entity.id] = entity

  # ASSETS

  showAsset: (id) ->
    asset = @assets[id]
    @_showAsset(asset)

  _showAsset: (asset) ->
    if asset.entities
      @_forEachEntity(asset, @showEntity)
    else if @isLayer asset
      @_showLayer asset
    # TODO(aramk) Only use camera of asset for assets, just zoom into entity otherwise.
    @zoomAsset asset.id

  zoomAsset: (id) ->
    asset = @assets[id]
    camera = asset.camera
    position = asset.position
    if camera
      elevation = camera.elevation
      if elevation != undefined
        position = _.defaults(position, {elevation: elevation})
    @_zoomTo(Setter.merge({position: position}, camera))

  hideAsset: (id) ->
    asset = @assets[id]
    if asset.entities
      @_forEachEntity(@assets[id], @hideEntity)
    else if @isLayer(asset)
      @_hideLayer(asset)

  # ENTITIES

  showEntity: (id) ->
    entity = @entities[id]
    asset = entity._asset || {}
    entity = Setter.merge({id: id}, asset.defaults, entity)
    @_showEntity(entity)

  _showEntity: (entity) ->
    id = entity.id
    publish = (showArg) =>
      @atlas.publish 'entity/show', showArg
    if !@atlas._managers.entity.getById id
      AtlasConverter.ready =>
        publish @converter.toGeoEntityArgs(entity)
    else
      publish({id: id})

  hideEntity: (id) ->
    @atlas.publish('entity/hide', {id: id})

  _forEachEntity: (asset, cb) ->
    _.each(asset.entities, (entity) =>
      cb.call(this, entity.id, entity))

  # LAYERS

  _showLayer: (layer) ->
    czmlUrl = layer.czmlUrl
    czml = layer.czml
    # TODO(aramk) Show the layer instead of creating again.
    if czml and czml.ids
      # IDs already set, so we have rendered before. Just show them.
      @atlas.publish('entity/show/bulk', {
        ids: czml.ids
      })
    else if czmlUrl
      czmlAbsUrl = new URI(czmlUrl).absoluteTo(layer._url)
      $.getJSON(czmlAbsUrl.toString(), (czml) =>
        @_showCzml(layer, czml))
    else if czml
      @_showCzml layer, czml
    else
      console.error('Unable to show layer', layer)

  _hideLayer: (layer) ->
    czml = layer.czml
    if czml.isImage
      # TODO(aramk) Support image layers.
    else
      @atlas.publish('entity/hide/bulk', {
        ids: czml.ids
      })

  isLayer: (asset) ->
    asset.czmlUrl != undefined || asset.czml != undefined

  # CZML

  _showCzml: (layer, czml) ->
    isImage = czml.isImage
    content = JSON.parse(czml.content)
    czml = layer.czml = {
      isImage: isImage,
      content: content
    }
    if czml.isImage
      # TODO(aramk) Support image layers.
    else
      @atlas.publish('entity/show/bulk', {
        features: content,
        callback: (ids) ->
          czml.ids = ids
      })

  # CAMERA

  _zoomTo: (args) ->
    @atlas.publish('camera/zoomTo', args)
