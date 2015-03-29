global = @

@SchemaUtils =

  getField: (fieldId, arg) -> Collections.getSchema(arg).schema(fieldId)

# Traverse the given schema and call the given callback with the field schema and ID.
  forEachFieldSchema: (schema, callback) ->
    fieldIds = schema._schemaKeys
    for fieldId in fieldIds
      fieldSchema = schema.schema(fieldId)
      if fieldSchema?
        callback(fieldSchema, fieldId)

  getSchemaReferenceFields: _.memoize(
    (collection) ->
      refFields = {}
      schema = collection.simpleSchema()
      SchemaUtils.forEachFieldSchema schema, (field, fieldId) ->
        if field.collectionType
          refFields[fieldId] = field
      refFields
    (collection) -> Collections.getName(collection)
  )

  getRefModifier: (model, collection, idMaps) ->
    modifier = {}
    $set = {}
    modifier.$set = $set
    refFields = @getSchemaReferenceFields(collection)
    _.each refFields, (field, fieldId) =>
      collectionName = Collections.getName(global[field.collectionType])
      # TODO(aramk) Refactor out logic for looking up fields in modifier format.
      oldId = @getModifierProperty(model, fieldId)
      newId = idMaps[collectionName][oldId]
      $set[fieldId] = newId
    modifier

  getParameterValue: (obj, paramId) ->
    # Allow paramId to optionally contain the prefix.
    paramId = ParamUtils.removePrefix(paramId)
    # Allow obj to contain "parameters" map or be the map itself.
    target = obj.parameters ? obj ?= {}
    @getModifierProperty(target, paramId)

  setParameterValue: (model, paramId, value) ->
    paramId = ParamUtils.removePrefix(paramId)
    target = model.parameters ?= {}
    @setModifierProperty(target, paramId, value)

  # TODO(aramk) Move to objects util.
  getModifierProperty: (obj, property) ->
    target = obj
    segments = property.split('.')
    unless segments.length > 0
      return undefined
    for key in segments
      target = target[key]
      unless target?
        break
    target

  # TODO(aramk) Move to objects util.
  setModifierProperty: (obj, property, value) ->
    segments = property.split('.')
    unless segments.length > 0
      return false
    lastSegment = segments.pop()
    target = obj
    for key in segments
      target = target[key] ?= {}
    target[lastSegment] = value
    true

  # TODO(aramk) Move to objects util.
  unflattenParameters: (doc, hasParametersPrefix) ->
    Objects.unflattenProperties doc, (key) ->
      if !hasParametersPrefix or /^parameters\./.test(key)
        key.split('.')
      else
        null
    doc

  mergeDefaultParameters: (model, defaults) ->
    model.parameters ?= {}
    Setter.defaults(model.parameters, defaults)
    model

  findByProjectSelector: (projectId) ->
    projectId ?= Projects.getCurrentId()
    if projectId
      {project: projectId}
    else
      throw new Error('No project ID provided.')

  findByProject: (collection, projectId) -> collection.find(@findByProjectSelector(projectId))

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
      fieldSchema = @getField(key, arg)
      if fieldSchema?.calc?
        schemas[key] = schema
    schemas

  getParamSchemas: (arg, paramIds) ->
    schemas = {}
    _.each paramIds, (paramId) =>
      field = @getField(ParamUtils.addPrefix(paramId), arg)
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
