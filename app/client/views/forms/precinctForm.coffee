Meteor.startup ->

  Form = Forms.defineModelForm
    name: 'precinctForm'
    collection: 'Precincts'
    onSuccess: ->
      Router.go('precincts');
    onCancel: ->
      Router.go('precincts');
