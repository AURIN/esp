TemplateClass = Template.projects;

goToPrecinctDesign = (id) ->
  Router.go('design', {_id: id})

TemplateClass.rendered = ->
  console.log('projects rendered');
  # TODO(aramk) This is here since the router doesn't call hooks when revisting...
  Session.set('stateName', 'Projects')
  # Add a launch button to the table toolbar.
  $table = $(@find('.collection-table'))
  $buttons = $('.on-selection-show', $table)
  # Duplicate button
  $btnDuplicate = $('<a class="duplicate item" title="Duplicate Project"><i class="copy icon"></i></a>')
  $btnDuplicate.on 'click', () ->
    id = $('.selected[data-id]', $table).data('id')
    Meteor.call('projects/duplicate', id)
  $buttons.append($btnDuplicate)
  # Launch button
  $btnLaunch = $('<a class="launch item" title="Launch Project"><i class="rocket icon"></i></a>')
  $btnLaunch.on 'click', () ->
    id = $('.selected[data-id]', $table).data('id')
    goToPrecinctDesign(id)
  $buttons.append($btnLaunch)

TemplateClass.helpers
  tableSettings: -> {
  fields: [
    key: 'name'
    label: 'Name'
  ]
  onEdit: (args) ->
    console.debug 'onEdit', arguments
    if args.event?.type == 'dblclick'
      goToPrecinctDesign(args.ids[0])
    else
      args.defaultHandler()
  onDelete: (args) ->
    Meteor.call('projects/remove', args.ids[0]);
  }
