Meteor.startup ->

  Form = Forms.defineModelForm
    name: 'lotForm'
    collection: 'Lots'
    onRender: ->

    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  Form.helpers
    classes: -> Typologies.toObjects()
    classValue: -> @doc?.parameters?.general?.class
