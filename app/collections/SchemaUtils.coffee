global = @

_.extend SchemaUtils,

  getParameterValues: (collection, paramId, args) ->
    args = _.extend({
      indexByValues: false
    }, args)
    values = {}
    _.each Collections.getItems(collection), (model) ->
      value = SchemaUtils.getParameterValue(model, paramId)
      if args.indexByValues
        models = values[value] ?= []
        models.push(model)
      else
        values[model._id] = value
    values

  getOutputParamSchemas: (arg, paramIds) ->
    schema = Collections.getSchema(arg)
    if paramIds
      paramIds = _.map paramIds, (paramId) -> ParamUtils.addPrefix(paramId)
    else
      paramIds = schema._schemaKeys
    schemas = {}
    for key in paramIds
      fieldSchema = Collections.getField(arg, key)
      if fieldSchema?.calc?
        schemas[key] = schema
    schemas

  getParamSchemas: (arg, paramIds) ->
    schemas = {}
    _.each paramIds, (paramId) =>
      paramId = ParamUtils.addPrefix(paramId)
      field = Collections.getField(arg, paramId)
      if field?
        schemas[paramId] = field
    schemas

if Meteor.isServer

  SchemaUtils.removeCalcFields = (arg) ->
    collection = Collections.get(arg)
    unless collection
      throw new Error('Could not resolve collection.')
    docs = Collections.getItems(arg)
    unless docs
      throw new Error('Could not resolve docs.')
    schemas = @getOutputParamSchemas(arg)
    $unset = {}
    _.each schemas, (schema, paramId) ->
      $unset[paramId] = null
    return 0 unless Object.keys($unset).length > 0
    total = 0
    _.each docs, (doc) ->
      total += collection.direct.update(doc._id, {$unset: $unset})
    total
