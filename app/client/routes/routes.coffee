#setStateName = (name) ->
#  Session.set('stateName', name)

BaseController = RouteController.extend
# Don't render until we're ready (waitOn) resolved
  action: -> @render() if @ready()

crudRoute = (collectionName, controller) ->
  controller ?= BaseController
  collectionId = Strings.firstToLowerCase(collectionName)
  singularName = Strings.singular(collectionId)
  itemRoute = singularName + 'Item'
  editRoute = singularName + 'Edit'
  formName = singularName + 'Form'
  console.debug('crud routes', itemRoute, editRoute, formName)
  Router.route collectionId,
    path: '/' + collectionId, controller: controller, template: collectionId
  Router.route itemRoute,
    path: '/' + collectionId + '/create', controller: controller, template: formName, data: -> {}
  Router.route editRoute,
    # Reuse the itemRoute for editing.
    path: '/' + collectionId + '/:_id/edit', controller: controller, template: formName,
    data: -> {doc: window[collectionName].findOne(@params._id)}

DesignController = BaseController.extend
  template: 'design'
  onBeforeAction: ->
    id = @.params._id
    Projects.setCurrentId(id)
    @next()

ProjectsController = BaseController.extend
  template: 'projects'
  waitOn: -> Meteor.subscribe('projects')

Router.route '/', -> @render('projects')

crudRoute('Projects', ProjectsController)

Router.route 'design',
  path: '/design/:_id'
  # TODO(aramk) Add action to the base controller and remove from routes.
  waitOn: -> _.map(['projects', 'entities', 'typologies'], (name) -> Meteor.subscribe(name))
  controller: DesignController

Router.onBeforeAction ->
  Router.initLastPath()
  @next()

# Allow storing the last route visited and switching back.
origGoFunc = Router.go
_lastPath = null
Router.setLastPath = (path, params) ->
  _lastPath = {path: path, params: params}
  console.debug('last router path', _lastPath)
Router.getLastPath = -> _lastPath
Router.goToLastPath = ->
  path = _lastPath.path
  if _lastPath? and Router.getCurrentPath() != path
    origGoFunc.call(Router, path, _lastPath.params)
    true
  else
    false

Router.setLastPathAsCurrent = ->
  current = Router.current()
  path = current.url
  return unless path
  Router.setLastPath(path, current.params)

Router.getCurrentPath = -> Iron.Location.get().path

# When switching, remember the last route.
Router.go = ->
  Router.setLastPathAsCurrent()
  origGoFunc.apply(@, arguments)

Router.initLastPath = ->
  unless _lastPath?
    Router.setLastPathAsCurrent()
