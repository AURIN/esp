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

    getValueOrCalc = (paramId) =>
      # NOTE: Parameters may reference other parameters which were not requested for evaluation, so
      # don't restrict searching to within the given paramIds.
      schema = @getParamSchema(paramId)
      unless schema
        throw new Error('Cannot find parameter with ID ' + paramId)
      # Use existing calculated value if available.
      value = getValue(paramId)
      if !value? && @isOutputParam(paramId)
        value = calcValue(paramId)
      value

    calcValue = (paramId) =>
      schema = @getParamSchema(paramId)
      calc = schema.calc
      if Types.isString(calc)
        calc = @buildEvalFunc(expr: calc)
      if Types.isFunction(calc)
        result = calc(getValueOrCalc, paramId, model, schema)
        # Store the calculated value to prevent calculating again.
        @setResult(model, paramId, result)
        result
      else
        throw new Error('Invalid calculation property - must be function, is of type ' +
          Types.getTypeOf(calc))

    getValue = (paramId) ->
      value = Entities.getParameter(model, paramId)
      unless value?
        # Lookup global value
        project = Projects.getCurrent()
        value = Entities.getParameter(project, paramId)
      value

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

  buildEvalFunc: (args) ->
    expr = args.expr
    # Replace the $ in the expression with a function call to retrieve the value.
    funcBody = 'return ' + expr.replace(/\$([\w.]+)/gi, 'param("$1")')
    new Function('param', funcBody)

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

  isOutputParam: (paramId) -> @getParamSchema(paramId).calc?
