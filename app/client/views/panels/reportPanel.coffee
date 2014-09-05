global = @
Reports = null
ReportTemplates = ['residentialReport']

currentReportId = null
currentReportTemplate = null
$reportPanelContent = null
$currentReport = null

renderReport = (id) ->
  # If the same report is rendered, keep the scroll position.
  scrollTop = null
  if currentReportId == id
    scrollTop = $reportPanelContent.scrollTop()
  currentReportId = id
  report = Reports.findOne(id)
  $currentReport = $('<div class="report-container"></div>')
  if scrollTop?
    # Wait until the report has rendered before setting scroll position.
    $currentReport.on 'render', ->
      $reportPanelContent.scrollTop(scrollTop)
  $reportPanelContent.empty()
  $reportPanelContent.append($currentReport)
  if currentReportTemplate
    TemplateUtils.getDom(currentReportTemplate).remove()
  name = report.templateName
  console.log 'Rendering report', name
  currentReportTemplate = UI.render(Template[name])
  UI.insert currentReportTemplate, $currentReport[0]
  PubSub.publish 'report/rendered', $currentReport

PubSub.subscribe 'report/refresh', ->
  renderReport(currentReportId)

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
  $reportPanelContent = $(@find('.content'))
  doRender = ->
    id = Template.dropdown.getValue($reportDropdown)
    renderReport(id)
    $refreshButton.show()
  $refreshButton.on 'click', doRender
  $reportDropdown.on 'change', doRender

Template.reportPanel.helpers
  reports: -> Reports
