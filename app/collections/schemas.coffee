global = @

@SchemaUtils =

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
    _.each refFields, (field, fieldId) ->
      collectionName = Collections.getName(global[field.collectionType])
      # TODO(aramk) Refactor out logic for looking up fields in modifier format.
      oldId = Typologies.getModifierProperty(model, fieldId)
      newId = idMaps[collectionName][oldId]
      $set[fieldId] = newId
    modifier
