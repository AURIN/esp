TemplateClass = Template.projects

goToPrecinctDesign = (id) ->
  Router.go('design', {_id: id})

TemplateClass.rendered = ->
  # TODO(aramk) This is here since the router doesn't call hooks when revisting...
  Session.set('stateName', 'Projects')
  # Add a launch button to the table toolbar.
  $table = $(@find('.collection-table'))
  getSelectedId = ->
    Template.collectionTable.getSelectedIds(Template.collectionTable.getDomTableId($table))[0]
  $buttons = $('.on-selection-show', $table)

  # Duplicate button
  $btnDuplicate = $('<a class="duplicate item" title="Duplicate"><i class="copy icon"></i></a>')
  $btnDuplicate.on 'click', =>
    id = getSelectedId()
    loaderNode = @find('.loader')
    Template.loader.setActive(loaderNode, true)
    Meteor.call 'projects/duplicate', id, (err, result) ->
      Template.loader.setActive(loaderNode, false)
  $buttons.append($btnDuplicate)
  
  # Export button
  $btnExport = $('<a class="export item" title="Export"><i class="down icon"></i></a>')
  $btnExport.on 'click', ->
    id = getSelectedId()
    ProjectUtils.downloadInBrowser(id)
  $buttons.append($btnExport)
  
  # Launch button
  $btnLaunch = $('<a class="launch item" title="Launch"><i class="rocket icon"></i></a>')
  $btnLaunch.on 'click', () ->
    id = getSelectedId()
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
