Meteor.startup ->

  close = ->
    unless Router.current().route.name == 'design'
      Router.goToLastPath() or Router.go('projects')

  Form = Forms.defineModelForm
    name: 'projectForm'
    collection: 'Projects'
    onSuccess: close
    onCancel: close
