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
    for paramId, schema of schemas
      try
        result = schema.calc(model.parameters ? {}, paramId, model, schema)
      catch e
        console.error('Failed to evaluate parameter', paramId, e)
      if result?
        changes[paramId] = result
        @setResult(model, paramId, result)
    changes

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
