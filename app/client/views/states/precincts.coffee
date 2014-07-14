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
  onEdit: (args) ->
    console.debug 'onEdit', arguments
    if args.event?.type == 'dblclick'
      Router.go('design', {_id: args.id})
    else
      args.defaultHandler()
  onDelete: (doc) ->
    # TODO(aramk)
    console.debug 'onDelete', arguments
  }
