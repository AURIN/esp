Meteor.startup ->

  Form = Forms.defineModelForm
    name: 'projectForm'
    collection: 'Projects'
    onSuccess: ->
      Router.go('projects');
    onCancel: ->
      Router.go('projects');
