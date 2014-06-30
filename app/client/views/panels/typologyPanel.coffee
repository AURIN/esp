Template.typologyPanel.created = ->
  @data = {}

Template.typologyPanel.helpers(
  'panelTitle': -> (if @.doc then 'Edit' else 'Create') + ' Typeology'
)