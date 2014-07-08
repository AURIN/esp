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
#    inputParamMap = {}
#    outputParamMap = {}
    for field in fields
      param = field.param
      if param?
        paramMap[param] = true
#        map = if field.expr then outputParamMap else inputParamMap
#        map[param] = true
#    inputParamIds = Object.keys(inputParamMap)
#    outputParamIds = Object.keys(outputParamMap)
    paramIds = Object.keys(paramMap)
    console.log('Generating report:')
    console.log('models', args.models)
#    console.log('parameters', outputParamIds)
#    evalResults = {}
    for model in models
      results = @evalEngine.evaluate(model: model, paramIds: paramIds)
#      for paramId in results
#        Entities.setParameter(model, paramId, results[paramId])
#      for paramId in inputParamIds
#        result[paramId] = Entities.getParameter(model, paramId)
#      evalResults[model._id] = result
    reportResults = {}
    for field in fields
      # Aggregate values for evaluated parameters across all models.
      paramId = field.param
      # TODO(aramk) Ignore header fields earlier.
      unless paramId?
        continue
#      paramResults = _.map evalResults, (result) -> result[paramId]
      paramResults = _.map models, (model) -> Entities.getParameter(model, paramId)
      reportResults[field.id] = Aggregator[aggregate](paramResults)
    reportResults
