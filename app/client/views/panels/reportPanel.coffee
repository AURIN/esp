evalEngine = null
reportGenerator = null

Meteor.startup ->
  evalEngine ?= new EvaluationEngine(schema: ParametersSchema)
  reportGenerator ?= new ReportGenerator(evalEngine: evalEngine)

Template.reportPanel.events
  'click .evaluate.button': (e, template) ->
    typologies = Typologies.find({}).fetch()
    console.log('evaluating', typologies)
    results = reportGenerator.generate(models: typologies)
    console.log('results', results)
