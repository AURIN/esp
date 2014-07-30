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

  # TODO

  showEntity: (id) ->

  hideEntity: (id) ->

