Reports = null
ReportTemplates = ['residentialReport']

Template.reportPanel.created = ->
  @data ?= {}
  Reports = Collections.createTemporary()
  # Add static reports to a temporary collection for populating the dropdown.
  for name in ReportTemplates
    template = Template[name]
    Reports.insert({templateName: name, name: template.title})
  @data.reports = Reports

Template.reportPanel.rendered = ->
  $reportDropdown = $(@find('.report.dropdown'))
  $refreshButton = $(@find('.refresh.button')).hide()
  reportTemplate = null
  $content = $(@find('.content'))
  renderReport = ->
    id = Template.dropdown.getValue($reportDropdown)
    report = Reports.findOne(id)
    $report = $('<div class="report"></div>')
    $content.empty()
    $content.append($report)
    if reportTemplate
      TemplateUtils.getDom(reportTemplate).remove()
    name = report.templateName
    console.log 'Rendering report', name
    reportTemplate = UI.render(Template[name])
    UI.insert reportTemplate, $report[0]
    $refreshButton.show()
  $refreshButton.on 'click', renderReport
  $reportDropdown.on 'change', renderReport

Template.reportPanel.helpers
  reports: -> Reports
