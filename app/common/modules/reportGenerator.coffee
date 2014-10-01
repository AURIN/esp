Aggregator =

  total: (values) ->
    total = 0
    for value in values
      if value? && !isNaN(value)
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
      fieldAggregate = field.aggregate ? aggregate
      if fieldAggregate? && fieldAggregate != false
        # Aggregate over all entities.
        paramResults = _.map models, (model) -> Entities.getParameter(model, paramId)
        result = Aggregator[fieldAggregate](paramResults)
      else if field.calc
        # Evaluate the field expression directly.
        # TODO(aramk) May not have a need for this.
        throw new Error('Calc expression in report field not yet supported')
      else
        console.error('Field ignored - must aggregate or provide calc expression.', field)
        continue
      reportResults[field.id] = result
    reportResults
