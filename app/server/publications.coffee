Meteor.publish 'features', -> Features.find()
Meteor.publish 'entities', -> Entities.find()
Meteor.publish 'typologies', -> Typologies.find()
