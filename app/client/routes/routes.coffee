BaseController = RouteController.extend
  onBeforeAction: ->
    return unless @ready()
    AccountsUi.signInRequired(@)
  # Don't render until we're ready (waitOn) resolved
  action: -> @render() if @ready()
  waitOn: -> Meteor.subscribe('userData')

DesignController = BaseController.extend
  template: 'design'
  onBeforeAction: ->
    id = @.params._id
    Projects.setCurrentId(id)
    AccountsUi.signInRequired(@)

ProjectsController = BaseController.extend
  template: 'projects'
  waitOn: ->
    return unless Meteor.user()
    [Meteor.subscribe('projects'), Meteor.subscribe('publicProjects')]
  onAfterAction: ->
    # Using onAfterAction so the project ID is still defined while the template is being destroyed
    # and doesn't cause reactive changes.
    Projects.setCurrentId(null)

Routes.config
  BaseController: BaseController

Router.route '/', -> Router.go('projects')

Meteor.startup ->
  Routes.crudRoute(Projects, {controller: ProjectsController})

Router.route 'design',
  path: '/design/:_id'
  waitOn: ->
    return unless Meteor.user()
    projectId = @params._id
    [Meteor.subscribe('projects'), Meteor.subscribe('publicProjects'),
      Meteor.subscribe('entities', projectId), Meteor.subscribe('typologies', projectId),
      Meteor.subscribe('lots', projectId), Meteor.subscribe('layers', projectId)]
  controller: DesignController
