Meteor.publish 'precincts', -> Precincts.find()
Meteor.publish 'entities', -> Entities.find()
Meteor.publish 'typologies', -> Typologies.find()
