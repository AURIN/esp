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
      result = schema.expr model.parameters, paramId, model, schema
      unless result == null
        changes[paramId] = result
        @setResult(model, paramId, result)
    changes

  getOutputParamSchemas: (paramIds) ->
    paramIds ?= @schema._schemaKeys
    schemas = {}
    _.each paramIds, (key) =>
      schema = @getParamSchema(key)
      schemas[key] = schema if schema.expr?
    schemas

  setResult: (model, paramId, value) ->
    model.parameters[paramId] = value

  getParamSchema: (paramId) ->
    @schema.schema(paramId)
