global = @
reports = null
ReportTemplates = [
  'residentialReport'
  'openSpaceReport'
  #'precinctReport'
]

reportPanelTemplate = null
currentReportId = null
currentReportTemplate = null
$reportPanelContent = null
$currentReport = null
precinctReportId = 'precinct'
renderDf = null

renderReport = (id) ->
  unless id?
    throw new Error('No report ID provided for rendering')
  report = reports.findOne(id)
  unless report?
    throw new Error('No such report with ID ' + report)
  # A promise for the rendered report fields
  renderDf = Q.defer()
  # If the same report is rendered, keep the scroll position.
  scrollTop = null
  if currentReportId == id
    scrollTop = $reportPanelContent.scrollTop()
  currentReportId = id
  $currentReport = $('<div class="report-container"></div>')
  if scrollTop?
    # Wait until the report has rendered before setting scroll position.
    $currentReport.on 'render', ->
      $reportPanelContent.scrollTop(scrollTop)
  $reportPanelContent.empty()
  $reportPanelContent.append($currentReport)
  if currentReportTemplate
    TemplateUtils.getDom(currentReportTemplate).remove()
  templateName = report.templateName
  ReportTemplate = Template[templateName]
  console.log 'Rendering report', templateName

  evalEngine = new EvaluationEngine(schema: Entities.simpleSchema())
  reportGenerator = new ReportGenerator(evalEngine: evalEngine)

  typologyClass = ReportTemplate.typologyClass
  typologyFilter = (entityId) ->
    entity = Entities.findOne(entityId)
    typology = Typologies.findOne(entity.typology)
    Typologies.getParameter(typology, 'general.class') == typologyClass

  # Use the selected entities, or all entities in the project.
  entityIds = AtlasManager.getSelectedFeatureIds()
  # Filter GeoEntity objects which are not project entities.
  entityIds = _.filter entityIds, (id) -> Entities.findOne(id)
  if entityIds.length > 0
    if typologyClass? && id != precinctReportId
      # If a typology class applies and we have made a selection, show the precinct report instead.
      hasMixedTypologies = _.some entityIds, (id) -> !typologyFilter(id)
      if hasMixedTypologies
        renderReport(precinctReportId)
        return
    entities = _.map entityIds, (id) -> Entities.getFlattened(id)
  else
    entities = Entities.getAllFlattenedInProject()
    if typologyClass?
      entities = _.filter entities, (entity) -> typologyFilter(entity._id)

  results = reportGenerator.generate(models: entities, fields: ReportTemplate.fields)
  console.debug('Report results', results)
  reportData =
    results: results
    entities: entities
  currentReportTemplate = UI.renderWithData(Template[templateName], reportData)
  UI.insert currentReportTemplate, $currentReport[0]
  PubSub.publish 'report/rendered', $currentReport
  $report = $(TemplateUtils.getDom(currentReportTemplate))
  $report.on 'render', (e, args) ->
    renderDf.resolve(args)
    # Place the header info into the report panel header
    $info = $('.info', $report)
    $panelHeader = reportPanelTemplate.$('.panel > .header')
    # Remove existing info element.
    $('.info', $panelHeader).detach()
    # Remove header from report since it's now empty.
    $('.header', $report).detach()
    $panelHeader.append($info)


refreshReport = -> renderReport(currentReportId) if currentReportId?
PubSub.subscribe 'report/refresh', -> refreshReport()

Template.reportPanel.created = ->
  reportPanelTemplate = @
  @data ?= {}
  reports = Collections.createTemporary()
  # Add static reports to a temporary collection for populating the dropdown.
  for name in ReportTemplates
    template = Template[name]
    reports.insert({templateName: name, name: template.title})
  @data.reports = reports
  # Listen for changes to the entity selection and refresh reports.
  AtlasManager.getAtlas().then (atlas) ->
    atlas.subscribe 'entity/selection/change', ->
      console.debug('entity/selection/change', @, arguments)
      refreshReport()

Template.reportPanel.rendered = ->
  $reportPanelContent = $(@find('.content'))
  $reportDropdown = $(@find('.report.dropdown'))
  $refreshButton = $(@find('.refresh.button'))
  $downloadButton = $(@find('.download.button'))
  $tools = $(@find('.tools')).hide()
  doRender = ->
    id = Template.dropdown.getValue($reportDropdown)
    renderReport(id)
    $refreshButton.show()
    $tools.show()
  $refreshButton.on 'click', doRender
  $downloadButton.on 'click', ->
    renderDf.promise.then (args) ->
      csv = Reports.toCSV(args.renderedFields)
      blob = Blobs.fromString(csv, type: 'text/csv;charset=utf-8;')
      report = reports.findOne(currentReportId)
      filename = report.name + '.csv'
      Blobs.downloadInBrowser(blob, filename)
  $reportDropdown.on 'change', doRender

Template.reportPanel.helpers
  reports: -> reports
