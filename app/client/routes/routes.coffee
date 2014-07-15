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
    Meteor.subscribe('precincts')
    # TODO(aramk) Waiting on more than one doesn't work.
#    _.map(['precincts', 'entities', 'typologies'], (name) -> Meteor.subscribe(name))
#  onBeforeAction: ->
#    console.log('onBeforeAction')
#    id = @.params._id
#    Session.set('precinctId', id)
#    precinct = Precincts.findOne(id)
#    setStateName(precinct.name)
#    Precincts.setCurrentId(id)

PrecinctsController = RouteController.extend
  template: 'precincts'
  waitOn: -> Meteor.subscribe('precincts')
  onBeforeAction: ->
#    console.log('onBeforeAction');
#    setStateName('Precincts')

crudRoute('Precincts', PrecinctsController)

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
    Router.go('precincts')

Router.map ->
  this.route 'design', {
    path: '/design/:_id'
    waitOn: ->
      console.log('waitOn 2')
      Meteor.subscribe('precincts')
#      _.map(['precincts', 'entities', 'typologies'], (name) -> Meteor.subscribe(name))
    controller: DesignController
  }
