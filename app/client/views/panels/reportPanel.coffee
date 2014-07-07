Reports = null

Template.reportPanel.created = ->
  @data ?= {}
  Reports = Collections.createTemporary()
  # Add static reports to a temporary collection for populating the dropdown.
  for name in ['openSpaceReport']
    template = Template[name]
    Reports.insert({templateName: name, name: template.title})
  @data.reports = Reports

Template.reportPanel.rendered = ->
  $reportDropdown = $(@find('.report.dropdown'))
  $refreshButton = $(@find('.refresh.button')).hide()
  reportTemplate = null
  $reports = $(@find('.reports'))
  renderReport = ->
    id = $reportDropdown.dropdown('get value')
    report = Reports.findOne(id)
    if reportTemplate
      reportTemplate.dom.remove()
    name = report.templateName
    console.log 'Rendering report', name
    reportTemplate = UI.render(Template[name])
    UI.insert reportTemplate, $reports[0]
    $refreshButton.show()
  $refreshButton.on 'click', renderReport
  $reportDropdown.on 'change', renderReport

Template.reportPanel.helpers
  reports: -> Reports
