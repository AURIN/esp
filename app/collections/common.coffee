SimpleSchema.debug = true
global = @

@Collections =

  allow: -> true
  allowAll: -> insert: @allow, update: @allow, remove: @allow

  # @param {Meteor.Collection|Cursor|String} arg
  # @returns {String}
  getCollectionName: (arg) ->
    collection = @getCollection(arg)
    # Meteor.Collection or LocalCollection.
    if collection then collection._name else arg.name

  # @param {String|Meteor.Collection|Cursor} arg
  getCollection: (arg) ->
    if Types.isString(arg)
      # Collection name.
      return global[arg]
    else if @isCursor(arg)
      return arg.collection
    else if @isCollection(arg)
      return arg
    else
      return null

  # @param obj
  # @returns {Boolean} Whether the given object is a collection.
  isCollection: (obj) ->
    obj instanceof Meteor.Collection

  # @param obj
  # @returns {Boolean} Whether the given object is a collection cursor.
  isCursor: (obj) ->
    obj.fetch != undefined

  # @param {Meteor.Collection|Cursor|Array} arg
  # @returns {Array} The items in the collection, or the cursor, or the original array passed.
  getCollectionItems: (arg) ->
    if Types.isArray(arg)
      return arg
    if Types.isString(arg)
      arg = @getCollection(arg)
    if @isCollection(arg)
      arg = arg.find({})
    if @isCursor(arg)
      return arg.fetch()
    return []
