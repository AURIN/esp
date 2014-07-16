Meteor.publish 'projects', -> Projects.find()
Meteor.publish 'entities', -> Entities.find()
Meteor.publish 'typologies', -> Typologies.find()
Meteor.publish 'files', -> Files.find()
