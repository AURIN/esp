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
  console.debug('crud routes', itemRoute, editRoute, formName);
  Router.map ->
    @route collectionId, {path: '/' + collectionId, controller: controller, template: collectionId}
    @route itemRoute,
      path: '/' + collectionId + '/create', controller: controller, template: formName
      data: -> {}
    @route editRoute,
      # Reuse the itemRoute for editing.
      path: '/' + collectionId + '/:_id/edit', controller: controller, template: formName
      data: -> {doc: window[collectionName].findOne(@params._id)}

#  onBeforeAction: ->
# This redirects users to a sign in form.
# TODO(aramk) Add back when we have auth.
#    AccountsEntry.signInRequired(@router)

DesignController = BaseController.extend
  template: 'design'
# TODO(aramk) Add action to the base controller and remove from routes.
#  waitOn: ->
#    _.map(['projects', 'entities', 'typologies'], (name) -> Meteor.subscribe(name))
#  action : -> @render() if @ready()
  onBeforeAction: ->
    id = @.params._id
    Projects.setCurrentId(id)

ProjectsController = BaseController.extend
  template: 'projects'
  waitOn: -> Meteor.subscribe('projects')

crudRoute('Projects')

Router.onBeforeAction (pause) ->
#  TODO(aramk) Add back when we have auth.
#  # Empty path is needed for page not found.
#  whiteList = ['', '/sign-in', '/sign-out', '/sign-up', '/forgot-password']
#  isWhiteListed = Arrays.trueMap(whiteList)[@path];
#  if !isWhiteListed && !Meteor.user()
#    @render('accessDenied')
#    pause()
#  else
  if @path == '/' || @path == ''
    Router.go('projects')
  Router.initLastPath()

Router.map ->
  @route 'design', {
    path: '/design/:_id'
    waitOn: -> _.map(['projects', 'entities', 'typologies'], (name) -> Meteor.subscribe(name))
    controller: DesignController
  }

# Allow storing the last route visited and switching back.
origGoFunc = Router.go
_lastPath = null
Router.setLastPath = (name, params) ->
  _lastPath = {name: name, params: params}
  console.debug('last router path', _lastPath)
Router.getLastPath = -> _lastPath
Router.goToLastPath = ->
  name = _lastPath.name
  current = Router.current()
  if _lastPath? and current.route.name != name
    origGoFunc.call(Router, name, _lastPath.params)
    true
  else
    false

Router.setLastPathAsCurrent = ->
  current = Router.current()
  if current
    Router.setLastPath(current.route.name, current.params)

# When switching, remember the last route.
Router.go = ->
  Router.setLastPathAsCurrent()
  origGoFunc.apply(@, arguments)

Router.initLastPath = ->
  unless _lastPath?
    Router.setLastPathAsCurrent()
