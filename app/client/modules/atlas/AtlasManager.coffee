instance = null

@AtlasManager =

  getInstance: -> instance

  setInstance: (_instance) -> instance = _instance

  zoomToProject: ->
    atlas = @getInstance()
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
    atlas = @getInstance()
    atlas.publish('camera/current', args)

  renderEntity: (entity) ->
    atlas = @getInstance()
    atlas.publish 'entity/show/bulk', {features: [entity]}

  unrenderEntity: (id) ->
    atlas = @getInstance()
    atlas.publish 'entity/remove', {id: id}

  getEntity: (id) ->
    atlas = @getInstance()
    atlas._managers.entity.getById(id)

  getFeatures: ->
    atlas = @getInstance()
    atlas._managers.entity.getFeatures()

  showEntity: (id) ->
    atlas = @getInstance()
    atlas.publish 'entity/show', {id: id}

  hideEntity: (id) ->
    atlas = @getInstance()
    atlas.publish 'entity/hide', {id: id}

  getDisplayModes: ->
    df = Q.defer()
    require ['atlas/model/Feature'], (Feature) ->
      items = _.map Feature.DisplayMode, (value, id) ->
        {label: Strings.toTitleCase(value), value: value}
      df.resolve(items)
    df.promise

  draw: (args) ->
    atlas = @getInstance()
    atlas.publish('entity/draw', args);

  stopDraw: (args) ->
    atlas = @getInstance()
    atlas.publish('entity/draw/stop', args);

  edit: (args) ->
    atlas = @getInstance()
    atlas.publish('edit/enable', args);

  stopEdit: ->
    atlas = @getInstance()
    atlas.publish('edit/disable');
