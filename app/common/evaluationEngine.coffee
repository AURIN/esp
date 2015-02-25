class @EvaluationEngine

  constructor: (args) ->
    @schema = args.schema
    unless @schema?
      throw new Error('No schema provided')

  evaluate: (args) ->
    args = _.extend({
      removeCalcFields: true
    }, args)
    model = args.model
    typologyClass = args.typologyClass
    changes = {}
    schemas = SchemaUtils.getOutputParamSchemas(@schema, args.paramIds)
    project = args.project ? Projects.findOne(model.project) ? Projects.getCurrent()
    unless project
      throw new Error('No project provided')
    project = Projects.mergeDefaults(project)

    getValueOrCalc = (paramId) =>
      # NOTE: Parameters may reference other parameters which were not requested for evaluation, so
      # don't restrict searching to within the given paramIds.
      unless @getParamSchema(paramId) || @isGlobalParam(paramId)
        throw new Error('Cannot find parameter with ID ' + paramId)
      # Use existing calculated value if available. NOTE: do not sanitize to allow checking whether
      # the value exists.
      value = getValue(paramId)
      if !value? && @isOutputParam(paramId)
        value = calcValue(paramId)
      @sanitizeParamValue(paramId, value)

    calcValue = (paramId) =>
      schema = @getParamSchema(paramId)
      calc = schema.calc
      if Types.isString(calc)
        calc = buildEvalFunc(paramId: paramId, expr: calc)
        schema.calc = calc
      if Types.isFunction(calc)
        addCalcContext(paramId, calc)
        result = calc.call(calc.context)
        result = @sanitizeParamValue(paramId, result)
        # Store the calculated value to prevent calculating again.
        @setResult(model, paramId, result)
        result
      else
        throw new Error('Invalid calculation property - must be function, is of type ' +
          Types.getTypeOf(calc))

    getValue = (paramId) =>
      value = SchemaUtils.getParameterValue(model, paramId)
      unless value?
        value = getGlobalValue(paramId)
      value

    getGlobalValue = (paramId) -> SchemaUtils.getParameterValue(project, paramId)

    buildEvalFunc = (args) ->
      expr = args.expr
      # Replace the $ in the expression with a function call to retrieve the value.
      funcBody = expr.replace(/\$([\w.]+)/gi, 'param("$1")')
      # Ensure existing function calls are on "this" context.
      funcBody = funcBody.replace(/(\w+)\s*\(/gi, 'this.$1(')
      funcBody = 'return ' + funcBody
      calc = new Function(funcBody)
      addCalcContext(args.paramId, calc)
      calc

    addCalcContext = (paramId, calc) =>
      schema = @getParamSchema(paramId)
      calc.context = _.defaults(_.extend(calc.context ? {}, {
        param: getValueOrCalc
        calc: (expr) ->
          subcalc = buildEvalFunc(paramId: paramId, expr: expr)
          subcalc.call(subcalc.context)
        paramId: paramId
        model: model
        schema: schema
      }), CalcContext)

    # Remove any calculated fields stored in the model which may be left from a previous session.
    if args.removeCalcFields
      _.each schemas, (schema, paramId) ->
        SchemaUtils.setParameterValue(model, paramId, undefined)

    # Go through output parameters and calculate them recursively.
    _.each schemas, (schema, paramId) ->
      classOptions = schema.classes
      # Ignore schema if field doesn't allow typology class.
      return if typologyClass? && classOptions? && !classOptions[typologyClass]
      # TODO(aramk) Detect cycles and throw exceptions to prevent infinite loops.
      try
        result = getValueOrCalc(paramId)
      catch e
        console.error('Failed to evaluate parameter', paramId, e)
      if result?
        changes[paramId] = result
    changes

  setResult: (model, paramId, value) ->
    SchemaUtils.setParameterValue(model, paramId, value)

  getParamSchema: (paramId) -> @schema.schema(ParamUtils.addPrefix(paramId))

  isOutputParam: (paramId) ->
    schema = @getParamSchema(paramId)
    if schema then schema.calc? else false

  sanitizeParamValue: (paramId, value) ->
    schema = @getParamSchema(paramId)
    if schema && schema.type == Number
      value = if (!value? || isNaN(value)) then NULL_VALUE else value
      # Round non-decimal values up.
      unless schema.decimal
        value = Math.round(value)
    value

  isGlobalParam: (paramId) -> Projects.simpleSchema().schema(ParamUtils.addPrefix(paramId))

NULL_VALUE = 0
sanitizeValue = (value) -> value ? 0

# Context object passed to each evaluation function. Allows passing functions for use in the
# schema expression.
CalcContext =
  IF: (condition, thenResult, elseResult) -> if condition then sanitizeValue(thenResult) else sanitizeValue(elseResult)
  KWH_TO_MJ: (kWh) -> kWh * 3.6
  MJ_TO_KWH: (MJ) -> MJ / 3.6
