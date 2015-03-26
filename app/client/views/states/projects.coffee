TemplateClass = Template.projects

goToPrecinctDesign = (id) ->
  Router.go('design', {_id: id})

TemplateClass.created = ->
  @showTemplates = new ReactiveVar(false)
  projects = @projects = Collections.createTemporary()
  @autorun =>
    showTemplates = @showTemplates.get()
    Tracker.nonreactive ->
      Collections.removeAllDocs(projects)
      Collections.copy(Projects.find(isTemplate: showTemplates), projects, {exclusive: true})

TemplateClass.rendered = ->
  # TODO(aramk) This is here since the router doesn't call hooks when revisting...
  Session.set('stateName', 'Projects')
  # Add a launch button to the table toolbar.
  $table = $(@find('.collection-table'))
  getSelectedId = -> Template.collectionTable.getSelectedIds($table)[0]
  $buttons = $('.on-selection-show', $table)

  # Duplicate button
  $btnDuplicate = $('<a class="duplicate item" title="Duplicate"><i class="copy icon"></i></a>')
  $btnDuplicate.on 'click', =>
    id = getSelectedId()
    loaderNode = @find('.loader')
    Template.loader.setActive(loaderNode, true)
    Meteor.call 'projects/duplicate', id, (err, result) =>
      Template.loader.setActive(loaderNode, false)
      # Switch back to showing the projects if we duplicated a template.
      showTemplates = @showTemplates.get()
      if showTemplates
        @showTemplates.set(false)
  $buttons.append($btnDuplicate)
  
  # Export button
  $btnExport = $('<a class="export item" title="Export"><i class="download icon"></i></a>')
  $btnExport.on 'click', ->
    id = getSelectedId()
    ProjectUtils.downloadInBrowser(id)
  $buttons.append($btnExport)
  
  # Launch button
  $btnLaunch = $('<a class="launch item" title="Launch"f><i class="rocket icon"></i></a>')
  $btnLaunch.on 'click', ->
    id = getSelectedId()
    goToPrecinctDesign(id)
  $buttons.append($btnLaunch)

  # Templates button
  $btnTemplates = $('<a class="ui toggle button templates item"><i class="file outline icon"></i></a>')
  $btnTemplates.state()
  $btnTemplates.on 'click', =>
    @showTemplates.set(!@showTemplates.get())
  $buttons.after($btnTemplates)
  
  @autorun =>
    showTemplates = @showTemplates.get()
    # Update title based on templates visibility.
    visibility = if showTemplates then 'Hide' else 'Show'
    $btnTemplates.attr('title', visibility + ' Templates')
    # Update template button state.
    $btnTemplates.toggleClass('active', showTemplates)

  $table.on 'select deselect', ->
    # Selecting a template project will hide all buttons but the duplicate button unless the user
    # is an admin.
    ids = Template.collectionTable.getSelectedIds($table)
    someTemplates = _.some ids, (id) -> Projects.findOne(id).isTemplate
    showButtons = !someTemplates || AuthUtils.isAdmin()
    $('>', $buttons).not($btnDuplicate).toggle(showButtons)

TemplateClass.helpers
  projects: -> getTemplate().projects
  tableSettings: ->
    fields: [
      key: 'name'
      label: 'Name'
    ]
    onEdit: (args) ->
      id = args.ids[0]
      return unless id
      model = args.collection.findOne(id)
      if model.isTemplate && !AuthUtils.isAdmin()
        alert('Only admin users can edit template projects. Click duplicate to create an ' +
          'editable copy.')
        return
      if args.event?.type == 'dblclick'
        goToPrecinctDesign(id)
      else
        args.defaultHandler()
    onDelete: (args) ->
      _.each args.ids, (id) ->
        Meteor.call('projects/remove', id)

getTemplate = -> Template.instance()
