Meteor.publish('features', function() {
  return Features.find();
});
