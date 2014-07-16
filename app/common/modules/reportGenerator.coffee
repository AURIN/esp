Aggregator =

  total: (values) ->
    total = 0
    for value in values
      if value?
        total += value
    total

  average: (values) ->
    len = (values.filter (value) -> value?).length
    if len > 0 then @total(values) / len else 0

class @ReportGenerator

  constructor: (args) ->
    @evalEngine = args.evalEngine

  generate: (args) ->
    models = args.models
    fields = args.fields
    aggregate = args.aggregate ? 'total'
    paramMap = {}
    for field in fields
      param = field.param
      if param?
        paramMap[param] = true
    paramIds = Object.keys(paramMap)
    console.log('Generating report:')
    console.log('models', args.models)
    for model in models
      # Evaluation result is stored in the model.
      @evalEngine.evaluate(model: model, paramIds: paramIds)
    reportResults = {}
    for field in fields
      # Aggregate values for evaluated parameters across all models.
      paramId = field.param
      # TODO(aramk) Ignore header fields earlier.
      unless paramId?
        continue
      paramResults = _.map models, (model) -> Entities.getParameter(model, paramId)
      reportResults[field.id] = Aggregator[aggregate](paramResults)
    reportResults
