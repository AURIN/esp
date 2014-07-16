TemplateClass = Template.projects;

TemplateClass.rendered = ->
  console.log('projects rendered');
  # TODO(aramk) This is here since the router doesn't call hooks when revisting...
  Session.set('stateName', 'Projects')

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
  onDelete: (args) ->
    id = args.id
    Meteor.call('projects/remove', id);
  }
