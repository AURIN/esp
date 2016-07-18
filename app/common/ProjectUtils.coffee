# Utilities dealing with projects.
_.extend ProjectUtils,

  # Returns a cursor for all public projects.
  getPublic: -> Projects.find(isPublic: true)

if Meteor.isServer

  # REST API for requesting public project data.

  HTTP.methods
    # Returns all meta-data for public projects JSON data.
    '/api/projects':
      get: ->
        @unblock()
        @addHeader('Content-Type', 'application/json')
        projects = ProjectUtils.getPublic().fetch()
        JSON.stringify(projects)
    
    # Returns the full data for the given project, including all entities, typologies, and lots
    # contained within.
    '/api/projects/:id':
      get: ->
        id = @params.id
        authorize(id)
        @addHeader('Content-Type', 'application/json')
        @unblock()
        json = ProjectUtils.toJson(id)
        JSON.stringify(json)
    
    # Returns a KMZ asset for the given project with all 2D geometry and extrusions.
    '/api/projects/:id/to/kmz':
      get: ->
        id = @params.id
        project = authorize(id)
        @unblock()
        result = EntityUtils.convertToKmz {projectId: id}
        @addHeader('Content-Disposition', 'attachment; filename="' + result.filename + '"')
        @addHeader('Content-Type', result.type)
        res = @createWriteStream()
        sbuff = Meteor.npmRequire('simple-bufferstream')
        sb = sbuff(result.buffer)
        sb.pipe(res)

    # Returns a C3ML asset (consumable by Atlas) for the given project with all geometry data.
    '/api/projects/:id/to/c3ml':
      get: ->
        id = @params.id
        project = authorize(id)
        @unblock()
        result = EntityUtils.convertToC3ml {projectId: id}
        @addHeader('Content-Disposition', 'attachment; filename="' + result.filename + '"')
        @addHeader('Content-Type', result.type)
        JSON.stringify(result.data)

# Determines whether the current project is accessible by the public REST API.
authorize = (projectId) ->
  check(projectId, String)
  project = Projects.findOne(projectId)
  unless project
    throw new Meteor.Error(500, 'Project with ID ' + projectId + ' not found')
  unless project.isPublic
    throw new Meteor.Error(403, 'Only public projects can be requested.')
  project
