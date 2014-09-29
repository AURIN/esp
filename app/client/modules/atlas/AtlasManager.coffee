atlas = null
atlasDf = null

init = ->
  atlas = null
  atlasDf = Q.defer()
init()

@AtlasManager =

  getAtlas: -> atlasDf.promise

  setAtlas: (_instance) ->
    @removeAtlas()
    atlas = _instance
    atlasDf.resolve(atlas)

  removeAtlas: ->
    init()

  zoomToProject: ->
    projectId = Projects.getCurrentId()
    location = Projects.getLocationCoords(projectId)
    if location.latitude? and location.longitude?
      location.elevation ?= 20000
      console.debug 'Loading project location', location
      atlas.publish 'camera/zoomTo', {position: location}
    else
      address = Projects.getLocationAddress(projectId)
      console.debug 'Loading project address', address
      atlas.publish 'camera/zoomTo', {address: address}

  getCurrentCamera: (args) ->
    atlas.publish('camera/current', args)

  renderEntity: (entityArgs) ->
    id = entityArgs.id
    unless id?
      throw new Error('Rendered entity must have ID.')
    atlas.publish 'entity/show/bulk', {features: [entityArgs]}
    entity = @getEntity(id)
    entity

  renderEntities: (entityArgs) ->
    entities = null
    atlas.publish 'entity/show/bulk', {
      features: entityArgs
      callback: (ids) ->
        entities = atlas._managers.entity.getByIds(ids)
    }
    entities

  unrenderEntity: (id) -> atlas.publish 'entity/remove', {id: id}

  getEntity: (id) -> atlas._managers.entity.getById(id)

  getFeatures: -> atlas._managers.entity.getFeatures()

  getSelectedFeatureIds: ->
    _.filter atlas._managers.selection.getSelectionIds(), (id) ->
      atlas._managers.entity.getById(id).getForm?

  getEntitiesByIds: (ids) -> atlas._managers.entity.getByIds(ids)

  showEntity: (id) -> atlas.publish 'entity/show', {id: id}

  hideEntity: (id) -> atlas.publish 'entity/hide', {id: id}

  getDisplayModes: ->
    df = Q.defer()
    require ['atlas/model/Feature'], (Feature) ->
      items = _.map Feature.DisplayMode, (value, id) ->
        {label: Strings.toTitleCase(value), value: value}
      df.resolve(items)
    df.promise

  draw: (args) -> atlas.publish('entity/draw', args);

  stopDraw: (args) -> atlas.publish('entity/draw/stop', args);

  edit: (args) -> atlas.publish('edit/enable', args);

  stopEdit: -> atlas.publish('edit/disable');
