global = @
reports = null
ReportTemplates = [
  'residentialReport'
  'commercialReport'
  'institutionalReport'
  'mixedUseReport'
  'openSpaceReport'
  'pathwayReport'
  'precinctReport',
  'transportReport'
  'cogenReport'
  'assetReport'
]

TemplateClass = Template.reportPanel
reportPanelTemplate = null
currentReportId = new ReactiveVar(null)
currentReportTemplate = null
$reportPanelContent = null
$currentReport = null
precinctReportId = 'precinctReport'
renderDf = null

renderReport = _.debounce(
  (id) ->
    # Delay rendering of reports until all entities and lots are rendered to ensure area
    # calculations do not fail. We should render the reports even if some entities failed to render.
    EntityUtils.renderAll().fin(-> _renderReport(id)).done()
  300
)

_renderReport = (id) ->
  unless id?
    throw new Error('No report ID provided for rendering')
  report = reports.findOne(id)
  unless report?
    currentReportId.set(null)
    throw new Error('No such report with ID ' + report)
  # A promise for the rendered report fields
  renderDf = Q.defer()
  # If the same report is rendered, keep the scroll position.
  scrollTop = null
  if currentReportId.get() == id
    scrollTop = $reportPanelContent.scrollTop()
  currentReportId.set(id)
  $reportDropdown = getReportsDropdown()
  $currentReport = $('<div class="report-container"></div>')
  if scrollTop?
    # Wait until the report has rendered before setting scroll position.
    $currentReport.on 'render', ->
      $reportPanelContent.scrollTop(scrollTop)
  clearPanel()
  $reportPanelContent.append($currentReport)
  getRefreshButton().show()
  getTools().show()
  templateName = report.templateName
  ReportTemplate = Template[templateName]
  Logger.info 'Rendering report', templateName

  evalEngine = new EvaluationEngine(schema: Entities.simpleSchema())
  reportGenerator = new ReportGenerator(evalEngine: evalEngine)

  typologyClass = ReportTemplate.typologyClass
  typologyFilter = (entityId) ->
    entity = Entities.findOne(entityId)
    Entities.getTypologyClass(entityId) == typologyClass

  # Use the selected entities, or all entities in the project.
  entityIds = AtlasManager.getSelectedFeatureIds()
  # Filter GeoEntity objects which are not project entities.
  entityIds = _.filter entityIds, (id) -> Entities.findOne(id)
  if entityIds.length > 0
    if typologyClass? && id != precinctReportId
      # If a typology class applies and we have made a selection with at least one incompatible
      # typology, show the precinct report instead.
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
  currentReportTemplate = Blaze.renderWithData(Template[templateName], reportData,
    $currentReport[0])
  PubSub.publish 'report/rendered', $currentReport
  $report = $(Templates.getElement(currentReportTemplate))
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

refreshReport = ->
  id = currentReportId.get()
  Template.dropdown.setValue(getReportsDropdown(), id)
  if id?
    renderReport(id)
  else
    clearPanel()

clearPanel = ->
  $reportPanelContent.empty()
  getTools().hide()
  reportPanelTemplate.$('.panel > .header .info').remove()
  if currentReportTemplate
    Templates.getElement(currentReportTemplate).remove()

TemplateClass.created = ->
  reportPanelTemplate = @
  @data ?= {}
  reports = Collections.createTemporary()
  # Add static reports to a temporary collection for populating the dropdown.
  for name in ReportTemplates
    template = Template[name]
    reports.insert({_id: name, templateName: name, name: template.title})
  @data.reports = reports
  # Listen for changes to the entity selection and refresh reports.
  AtlasManager.getAtlas().then (atlas) ->
    atlas.subscribe 'entity/selection/change', (args) ->
      changed = _.union(args.selected, args.deselected)
      entities = _.filter changed, (id) -> Entities.findOne(id)
      if entities.length > 0 then refreshReport()

TemplateClass.rendered = ->
  $reportPanelContent = @$('.content')
  $reportDropdown = getReportsDropdown()
  clearPanel()
  
  getRefreshButton().on 'click', refreshReport
  getDownloadButton().on 'click', ->
    renderDf.promise.then (args) ->
      csv = Reports.toCSV(args.renderedFields)
      blob = Blobs.fromString(csv, type: 'text/csv;charset=utf-8;')
      report = reports.findOne(currentReportId.get())
      filename = report.name + '.csv'
      Blobs.downloadInBrowser(blob, filename)
  $reportDropdown.on 'change', ->
    # NOTE: Null default value is provided to avoid fluctuating between "" and null since dropdown
    # will give value as "" when empty, causing the reactive variable to become null, causing the
    # dropdown to become "" and so forth.
    id = Template.dropdown.getValue($reportDropdown) || null
    currentReportId.set(id)
  
  @pubsubTokens = []
  @pubsubTokens.push PubSub.subscribe 'report/refresh', -> refreshReport()
  
  # Refresh report on changes to the current report. Don't render the report until told to so
  # Atlas entities are rendered beforehand and GFA can be calculated.
  shouldRun = false
  @autorun ->
    id = currentReportId.get()
    return unless shouldRun
    refreshReport()
  shouldRun = true

TemplateClass.destroyed = ->
  currentReportId.set(null)
  _.each @pubsubTokens, (token) -> PubSub.unsubscribe(token)

TemplateClass.helpers
  reports: -> reports

getRefreshButton = -> reportPanelTemplate.$('.refresh.button')
getReportsDropdown = -> reportPanelTemplate.$('.report.dropdown')
getDownloadButton = -> reportPanelTemplate.$('.download.button')
getTools = -> reportPanelTemplate.$('.tools').hide()
