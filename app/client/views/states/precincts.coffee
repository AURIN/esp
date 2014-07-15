TemplateClass = Template.precincts;

TemplateClass.rendered = ->
  console.log('precincts rendered');
  # TODO(aramk) This is here since the router doesn't call hooks when revisting...
  Session.set('stateName', 'Precincts')

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
    event = args.event
    if event?.type == 'dblclick'
      id = $(event.target).closest('tr').data('id');
      Router.go('design', {_id: id})
    else
      args.defaultHandler()
  onDelete: (args) ->
    id = args.id
    Meteor.call('precincts/remove', id);
  }
