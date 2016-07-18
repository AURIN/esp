# Generates report output.
class @ReportGenerator

  # `args.evalEngine` - An instance of the EvaluationEngine.
  constructor: (args) ->
    @evalEngine = args.evalEngine

  # Generates report output given the following:
  #  * `args.models` - An array of documents to run through the evaluation engine.
  #  * `args.fields` - An array of output fields from a schema to include in the report output.
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
    allResults = []
    for model in models
      # Evaluation result is stored in the model.
      typologyClass = Entities.getTypologyClass(model)
      results = @evalEngine.evaluate(model: model, paramIds: paramIds, typologyClass: typologyClass)
      allResults.push(results)
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
        paramResults = _.map allResults, (results) -> results[ParamUtils.addPrefix(paramId)]
        result = Aggregator[fieldAggregate](paramResults)
      else if field.calc
        # Evaluate the field expression directly.
        # TODO(aramk) May not have a need for this.
        throw new Error('Calc expression in report field not yet supported')
      else
        Logger.error('Field ignored - must aggregate or provide calc expression.', field)
        continue
      reportResults[field.id] = result
    reportResults

# Calculates aggregations of values.
Aggregator =

  # Returns the sum of all given values.
  total: (values) ->
    total = 0
    for value in values
      if Numbers.isDefined(value)
        total += value
    total

  # Calculates the mean of the given values.
  average: (values) ->
    len = (values.filter (value) -> value?).length
    if len > 0 then @total(values) / len else 0
