Meteor.methods

  # TODO(aramk) Currently this uses Catalyst server methods. We will eventually change to ACS.

  'assets/import': (fileId) ->
    data = Meteor.call 'files/getData', fileId
    Meteor.call 'catalyst/login'
    asset = Meteor.call 'catalyst/assets/upload', data
    asset
#    data = Meteor.call 'catalyst/assets/download', asset.id
#    console.log 'data', data

  'assets/synthesize': (request) ->
    Meteor.call 'catalyst/assets/synthesize', request


  'assets/formats': ->
    Meteor.call 'catalyst/login'
    Meteor.call 'catalyst/assets/formats'
