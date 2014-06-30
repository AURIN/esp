Meteor.publish 'features', ->
  Features.find()

Meteor.publish 'typologies', ->
  Typologies.find()
