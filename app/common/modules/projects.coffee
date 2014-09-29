# Constructs a map of collection name to collection.
# TODO(aramk) Move to Collections utility class.
getCollectionNameMap = (collections) ->
  collectionMap = {}
  _.each collections, (collection) ->
    name = Collections.getName(collection)
    collectionMap[name] = collection
  collectionMap

# Used to change references in the models of each collection. Since each collection has a unique
#referenceTransformers = {}

@ProjectUtils =

# @param {String} id - The ID of the project to serialize.
# @returns {Object} JSON serialization of the given project and its models. IDs are unaltered.
  toJSON: (id) ->
    project = Projects.findOne(id)
    unless project
      throw new Error('Project with ID ' + id + ' not found')
    result = {}
    result[Collections.getName(Projects)] = [project]
    _.each getCollectionNameMap([Entities, Typologies, Lots]), (collection, name) ->
      result[name] = collection.findByProject(id)
    result

# Constructs new models from the given JSON serialization. IDs are used to retain references between
# the new models and new IDs are generated to replace those in the given JSON.
# @param {Object} json - The serialized JSON. This object may be modified by this method - pass a
# clone if this is undesirable.
# @param {Object} args
# TODO(aramk) Add support for this or remove the option.
# @param {Boolean} args.update - If true, no new models will be constructed. Instead, any existing
# models matching with matching IDs will be updated with the values in the given JSON.
  fromJSON: (json, args) ->
    # Construct all models as new documents in the first pass, mapping old ID references to new IDs.
    # In the second pass, change all IDs to the new ones to maintain references in the new models.

    df = Q.defer()
    # A map of collection names to maps of model IDs from the input to the new IDs constructed.
    idMaps = {}

    createDfs = []
    collectionMap = getCollectionNameMap([Projects, Entities, Typologies, Lots])
    _.each collectionMap, (collection, name) ->
      idMap = idMaps[name] = {}
      _.each json[name], (model) ->
        createDf = Q.defer()
        createDfs.push(createDf.promise)
        oldModelId = model._id
        delete model._id
        collection.insert model, (err, result) ->
          if err
            createDf.reject(err)
          else
            newModelId = result
            idMap[oldModelId] = newModelId
            createDf.resolve(newModelId)

    refDfs = []
    Q.all(createDfs).then(
      ->
        _.each idMaps, (idMap, name) ->
          collection = collectionMap[name]
          _.each idMap, (newId, oldId) ->
            modifier = SchemaUtils.getRefModifier(collection.findOne(newId), collection, idMaps)
            if Object.keys(modifier.$set).length > 0
              refDf = Q.defer()
              refDfs.push(refDf.promise)
              collection.update newId, modifier, (err, result) ->
                if err
                  refDf.reject(err)
                else
                  refDf.resolve(newId)
      (err) -> df.reject(err)
    )

    Q.all(refDfs).then(
      -> df.resolve(idMaps)
      # TODO(aramk) Remove added models on failure.
      (err) -> df.reject(err)
    )
    df.promise
