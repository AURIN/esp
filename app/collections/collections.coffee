SimpleSchema.debug = true
SimpleSchema.extendOptions
# Optional extra fields.
  desc: Match.Optional(String)
  units: Match.Optional(String)

global = @

@Collections =

  allow: -> true
  allowAll: -> insert: @allow, update: @allow, remove: @allow

# @param {Meteor.Collection|Cursor|String} arg
# @returns {String}
  getName: (arg) ->
    collection = @get(arg)
    # Meteor.Collection or LocalCollection.
    if collection then collection._name else arg.name

  getTitle: (arg) ->
    Strings.toTitleCase(@getName(arg))

# @param {String|Meteor.Collection|Cursor} arg
  get: (arg) ->
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
  getItems: (arg) ->
    if Types.isArray(arg)
      return arg
    if Types.isString(arg)
      arg = @get(arg)
    if @isCollection(arg)
      arg = arg.find({})
    if @isCursor(arg)
      return arg.fetch()
    return []
