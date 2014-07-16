Meteor.startup ->

  Form = Forms.defineModelForm
    name: 'projectForm'
    collection: 'Projects'
    onSuccess: ->
      Router.goToLastPath() or Router.go('projects')
    onCancel: ->
      Router.goToLastPath() or Router.go('projects')
