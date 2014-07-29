Meteor.startup ->

  Form = Forms.defineModelForm
    name: 'lotForm'
    collection: Lots
    onRender: ->

    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  Form.helpers
    classes: -> _.map Typologies.classes, (name, id) -> {_id: id, name: name}
    classValue: -> @doc?.parameters?.general?.class
