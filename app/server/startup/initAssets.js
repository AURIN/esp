Meteor.startup(function () {
  var features = [
    Assets.getText('assets/unimelb.json')
  ];
  _.each(features, function (json) {
    var feature = JSON.parse(json);
    var name = feature.name;
    var existing = Features.findOne({name: name});
    if (!existing) {
      Features.insert(feature);
      console.log('Inserted feature with ID', name);
    }
  });
});