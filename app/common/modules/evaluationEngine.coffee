class @EvaluationEngine

  constructor: (args) ->
    # {@type} SimpleSchema
    @schema = args.schema
    unless @schema?
      throw new Error('No schema provided')

  evaluate: (args) ->
    model = args.model
    changes = {}
    schemas = @getOutputParamSchemas(args.paramIds)
    project = Projects.mergeDefaults(Projects.getCurrent())

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
        calc = buildEvalFunc(expr: calc)
        schema.calc = calc
      if Types.isFunction(calc)
        addCalcContext(calc)
        result = calc.call(calc.context)
        result = @sanitizeParamValue(paramId, result)
        # Store the calculated value to prevent calculating again.
        @setResult(model, paramId, result)
        result
      else
        throw new Error('Invalid calculation property - must be function, is of type ' +
          Types.getTypeOf(calc))

    getValue = (paramId) =>
      value = Entities.getParameter(model, paramId)
      unless value?
        value = getGlobalValue(paramId)
      value

    getGlobalValue = (paramId) -> Entities.getParameter(project, paramId)

    buildEvalFunc = (args) ->
      expr = args.expr
      # Replace the $ in the expression with a function call to retrieve the value.
      funcBody = expr.replace(/\$([\w.]+)/gi, 'param("$1")')
      # Ensure existing function calls are on "this" context.
      funcBody = funcBody.replace(/(\w+)\s*\(/gi, 'this.$1(')
      funcBody = 'return ' + funcBody
      calc = new Function(funcBody)
      addCalcContext(calc)
      calc

    # TODO(aramk) Refactor
    addCalcContext = (calc) ->
      calc.context = _.defaults(_.extend(calc.context ? {}, {
        param: getValueOrCalc
        paramId: paramId
        model: model
        schema: schema
      }), CalcContext)

    # Go through output parameters and calculate them recursively.
    for paramId, schema of schemas
      # TODO(aramk) Detect cycles and throw exceptions to prevent infinite loops.
      # TODO(aramk) Avoid re-calculating values.
      try
        result = getValueOrCalc(paramId)
      catch e
        console.error('Failed to evaluate parameter', paramId, e)
      if result?
        changes[paramId] = result
    changes

  getOutputParamSchemas: (paramIds) ->
    unless paramIds
      paramIds = @schema._schemaKeys
    schemas = {}
    for key in paramIds
      key = ParamUtils.addPrefix(key)
      schema = @getParamSchema(key)
      if schema?
        if schema.calc?
          # Skip input fields which never need to be evaluated.
          schemas[key] = schema
      else
        console.error('Skipping unknown parameter', key, 'not found in schema', schema)
    schemas

  setResult: (model, paramId, value) ->
    Entities.setParameter(model, paramId, value)

  getParamSchema: (paramId) -> @schema.schema(ParamUtils.addPrefix(paramId))

  isOutputParam: (paramId) ->
    schema = @getParamSchema(paramId)
    if schema then schema.calc? else false

  sanitizeParamValue: (paramId, value) ->
    schema = @getParamSchema(paramId)
    if schema && schema.type == Number && (!value? || isNaN(value)) then NULL_VALUE else value

  isGlobalParam: (paramId) -> Projects.schema.schema(ParamUtils.addPrefix(paramId))

NULL_VALUE = 0
sanitizeValue = (value) -> value ? 0

# Context object passed to each evaluation function. Allows passing functions for use in the
# schema expression.
CalcContext =
  IF: (condition, thenResult, elseResult) -> if condition then sanitizeValue(thenResult) else sanitizeValue(elseResult)
  KWH_TO_MJ: (kWh) -> kWh * 3.6
  MJ_TO_KW: (mj) -> mj / 3.6
