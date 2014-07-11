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
    console.log('param schemas', schemas)
    paramGetter = (name) ->
      Entities.getParameter(model, name)
    for paramId, schema of schemas
      try
        calc = schema.calc
        if Types.isString(calc)
          calc = @buildEvalFunc(expr: calc)
        if Types.isFunction(calc)
          result = calc(paramGetter, paramId, model, schema)
        else
          throw new Error('Invalid calculation property - must be function, is of type ' +
            Types.getTypeOf(calc))
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
    paramIds ?= @schema._schemaKeys
    schemas = {}
    for key in paramIds
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

  getParamSchema: (paramId) ->
    @schema.schema(paramId)

  isOutputParam: (paramId) ->
    @getParamSchema(paramId).calc?
