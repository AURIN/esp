#setStateName = (name) ->
#  Session.set('stateName', name)

AuthController = RouteController.extend({})

crudRoute = (collectionName, controller) ->
  controller ?= AuthController
  collectionId = Strings.firstToLowerCase(collectionName)
  singularName = Strings.singular(collectionId)
  itemRoute = singularName + 'Item'
  editRoute = singularName + 'Edit'
  formName = singularName + 'Form'
  console.log('crud routes', itemRoute, editRoute, formName);
  Router.map ->
    this.route collectionId, {path: '/' + collectionId, controller: controller, template: collectionId}
    this.route itemRoute,
      path: '/' + collectionId + '/create', controller: controller, template: formName
      data: -> {}
    this.route editRoute,
      # Reuse the itemRoute for editing.
      path: '/' + collectionId + '/:_id/edit', controller: controller, template: formName
      data: -> {doc: window[collectionName].findOne(this.params._id)}

#  onBeforeAction: ->
# This redirects users to a sign in form.
# TODO(aramk) Add back when we have auth.
#    AccountsEntry.signInRequired(this.router)

DesignController = RouteController.extend
  template: 'design'
  waitOn: ->
    console.log('waitOn 1')
    Meteor.subscribe('projects')
    # TODO(aramk) Waiting on more than one doesn't work.
#    _.map(['projects', 'entities', 'typologies'], (name) -> Meteor.subscribe(name))
  onBeforeAction: ->
#    console.log('onBeforeAction')
    id = @.params._id
    Projects.setCurrentId(id)
#    Session.set('projectId', id)
#    project = Projects.findOne(id)
#    setStateName(project.name)
#    Projects.setCurrentId(id)

ProjectsController = RouteController.extend
  template: 'projects'
  waitOn: -> Meteor.subscribe('projects')
  onBeforeAction: ->
#    console.log('onBeforeAction');
#    setStateName('Projects')

crudRoute('Projects')

Router.onBeforeAction (pause) ->
#  TODO(aramk) Add back when we have auth.
#  # Empty path is needed for page not found.
#  whiteList = ['', '/sign-in', '/sign-out', '/sign-up', '/forgot-password']
#  isWhiteListed = Arrays.trueMap(whiteList)[this.path];
#  if !isWhiteListed && !Meteor.user()
#    this.render('accessDenied')
#    pause()
#  else
  if this.path == '/' || this.path == ''
    Router.go('projects')
  Router.initLastPath()

Router.map ->
  this.route 'design', {
    path: '/design/:_id'
    waitOn: ->
      console.log('waitOn 2')
      Meteor.subscribe('projects')
#      _.map(['projects', 'entities', 'typologies'], (name) -> Meteor.subscribe(name))
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
