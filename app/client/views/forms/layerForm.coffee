Meteor.startup ->

  Form = Forms.defineModelForm
    name: 'layerForm'
    collection: Layers
    onRender: ->
    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  Form.helpers
    types: -> Layers
    displayModes: -> Layers.getDisplayModeItems()
    # displayMode: -> LayerUtils.getDisplayMode(@doc?._id)
