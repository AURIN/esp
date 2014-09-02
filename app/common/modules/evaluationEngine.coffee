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
    # Go through output parameters and calculate them recursively.
    getOutputParamSchema = (paramId) -> schemas[ParamUtils.addPrefix(paramId)]

    getValueOrCalc = (paramId) =>
      if getOutputParamSchema(paramId)
        # Only output fields are in this schema object.
        value = calcValue(paramId)
      else
        if @getParamSchema(paramId)
          value = getValue(paramId)
        else
          throw new Error('Cannot find parameter with ID ' + paramId)
      value

    calcValue = (paramId) =>
      schema = getOutputParamSchema(paramId)
      calc = schema.calc
      if Types.isString(calc)
        calc = @buildEvalFunc(expr: calc)
      if Types.isFunction(calc)
        calc(getValueOrCalc, paramId, model, schema)
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

    for paramId, schema of schemas
      # TODO(aramk) Detect cycles and throw exceptions to prevent infinite loops.
      # TODO(aramk) Avoid re-calculating values.
      try
        result = calcValue(paramId)
      catch e
        console.error('Failed to evaluate parameter', paramId, e)
      if result?
        changes[paramId] = result
        @setResult(model, paramId, result)
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
