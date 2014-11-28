global = @

@SchemaUtils =

  getField: (fieldId, collection) -> collection.simpleSchema().schema(fieldId)

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
