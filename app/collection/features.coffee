Features = new Meteor.Collection('features')
allow () ->
  true

Features.allow
  insert: allow
  update: allow
  remove: allow
