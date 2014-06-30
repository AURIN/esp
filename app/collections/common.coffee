SimpleSchema.debug = true

@Collections =
  allow: -> true
  allowAll: -> insert: @allow, update: @allow, remove: @allow
