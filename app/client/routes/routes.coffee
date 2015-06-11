BaseController = RouteController.extend
  onBeforeAction: ->
    return unless @ready()
    AccountsAurin.signInRequired(@)
  # Don't render until we're ready (waitOn) resolved
  action: -> @render() if @ready()
  waitOn: -> Meteor.subscribe('userData')

crudRoute = (collectionName, controller) ->
  controller ?= BaseController
  collectionId = Strings.firstToLowerCase(collectionName)
  singularName = Strings.singular(collectionId)
  itemRoute = singularName + 'Create'
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
    AccountsAurin.signInRequired(@)

ProjectsController = BaseController.extend
  template: 'projects'
  waitOn: ->
    return unless Meteor.user()
    [Meteor.subscribe('projects'), Meteor.subscribe('publicProjects')]
  onAfterAction: ->
    # Using onAfterAction so the project ID is still defined while the template is being destroyed
    # and doesn't cause reactive changes.
    Projects.setCurrentId(null)

Router.route '/', -> Router.go('projects')

crudRoute('Projects', ProjectsController)

Router.route 'design',
  path: '/design/:_id'
  waitOn: ->
    return unless Meteor.user()
    projectId = @params._id
    [Meteor.subscribe('projects'), Meteor.subscribe('publicProjects'),
      Meteor.subscribe('entities', projectId), Meteor.subscribe('typologies', projectId),
      Meteor.subscribe('lots', projectId), Meteor.subscribe('layers', projectId)]
  controller: DesignController

Router.onBeforeAction ->
  Router.initLastPath()
  AccountsAurin.signInRequired(@)

# Allow storing the last route visited and switching back.
origGoFunc = Router.go
_lastPath = null
Router.setLastPath = (path, params) ->
  _lastPath = {path: path, params: params}
  console.debug('last router path', _lastPath)
Router.getLastPath = -> _lastPath
Router.goToLastPath = ->
  currentPath = Router.getCurrentPath()
  lastPath = Router.getLastPath()
  if lastPath? && lastPath.path? && lastPath.path != currentPath.path
    origGoFunc.call(Router, lastPath.path, lastPath.params)
    true
  else
    false

Router.setLastPathAsCurrent = ->
  current = Router.getCurrentPath()
  Router.setLastPath(current.path, current.params)

Router.getCurrentName = -> Router.current().route.getName()
Router.getCurrentPath = ->
  current = Router.current()
  # Remove the host prefix from the path, which is sometimes present.
  {
    path: Iron.Location.get().path
    params: current?.params
  }

# When switching, remember the last route.
Router.go = ->
  Router.setLastPathAsCurrent()
  origGoFunc.apply(@, arguments)

Router.initLastPath = ->
  unless _lastPath?
    Router.setLastPathAsCurrent()
