global = @
Reports = null
ReportTemplates = ['residentialReport']

currentReportId = null
currentReportTemplate = null
$reportPanelContent = null
$currentReport = null
precinctReportId = 'precinct'

renderReport = (id) ->
  unless id?
    throw new Error('No report ID provided for rendering')
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
  templateName = report.templateName
  ReportTemplate = Template[templateName]
  console.log 'Rendering report', templateName

  # TODO(aramk) Filter based on selected entities/typologies with Session.get

  evalEngine = new EvaluationEngine(schema: Entities.schema)
  reportGenerator = new ReportGenerator(evalEngine: evalEngine)

  typologyClass = ReportTemplate.typologyClass
  typologyFilter = (entityId) ->
    entity = Entities.findOne(entityId)
    console.log('arguments', arguments)
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
    entities = Entities.getAllFlattened()
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

refreshReport = -> renderReport(currentReportId)
PubSub.subscribe 'report/refresh', -> refreshReport()

Template.reportPanel.created = ->
  @data ?= {}
  Reports = Collections.createTemporary()
  # Add static reports to a temporary collection for populating the dropdown.
  for name in ReportTemplates
    template = Template[name]
    Reports.insert({templateName: name, name: template.title})
  @data.reports = Reports
  # Listen for changes to the entity selection and refresh reports.
  AtlasManager.getAtlas().then (atlas) ->
    atlas.subscribe 'entity/selection/change', ->
      console.debug('entity/selection/change', @, arguments)
      refreshReport() if currentReportId?

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
