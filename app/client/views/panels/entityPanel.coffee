Template.entityPanel.created = ->
  @data = {}

Template.entityPanel.helpers(
  'panelTitle': -> (if @.doc then 'Edit' else 'Create') + ' Entity'
)