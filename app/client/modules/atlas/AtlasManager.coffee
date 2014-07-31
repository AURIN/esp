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
    atlas.publish 'entity/show', entity

  unrenderEntity: (id) ->
    atlas = @getInstance()
    atlas.publish 'entity/remove', {id: id}

  getEntity: (id) ->
    atlas = @getInstance()
    atlas._managers.entity.getById(id)

  showEntity: (id) ->
    atlas = @getInstance()
    atlas.publish 'entity/show', {id: id}

  hideEntity: (id) ->
    atlas = @getInstance()
    atlas.publish 'entity/hide', {id: id}

