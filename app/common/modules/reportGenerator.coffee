Aggregator =

  total: (values) ->
    total = 0
    for value in values
      if value?
        total += value
    total

  average: (values) ->
    len = values.length
    if len > 0 then @total(values) / len else 0

class @ReportGenerator

  constructor: (args) ->
    @evalEngine = args.evalEngine

  generate: (args) ->
    models = args.models
    paramIds = args.paramIds ?= Object.keys(@evalEngine.getOutputParamSchemas())
    aggregate = args.aggregate ? 'total'
    evalResults = []
    for model in models
      result = @evalEngine.evaluate(model: model, paramIds: paramIds)
      evalResults.push result
    results = {}
    for paramId in paramIds
      paramResults = _.map evalResults, (result) -> result[paramId]
      results[paramId] = Aggregator[aggregate](paramResults)
    results
