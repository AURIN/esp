Meteor.startup ->
  features = [
    Assets.getText('assets/unimelb.json')
  ]
  _.each features, (json) ->
    feature = JSON.parse(json)
    name = feature.name
    existing = Features.findOne(name: name)
    if !existing
      Features.insert(feature)
      console.log('Inserted feature with ID', name)
