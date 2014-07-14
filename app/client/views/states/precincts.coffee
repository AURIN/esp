TemplateClass = Template.precincts;

TemplateClass.rendered = ->

TemplateClass.helpers
  tableSettings: -> {
    fields: [
      key: 'name'
      label: 'Name'
    ]
#    onCreate: (data) ->
#      collectionName = Collections.getName(data.collection)
#      formName = collectionToForm[collectionName]
      # TODO(aramk)
#      console.debug 'onCreate', arguments
#    onEdit: (data, doc) ->
#      # TODO(aramk)
#      console.debug 'onEdit', arguments
    onDelete: (doc) ->
      # TODO(aramk)
      console.debug 'onDelete', arguments
  }
