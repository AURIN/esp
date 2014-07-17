Meteor.methods

  'assets/import': (fileId) ->
    data = Meteor.call 'files/getData', fileId
#    console.log 'data', data
    loginResult = Meteor.call('catalyst/login')
    console.log('catalyst server login', loginResult)
#    projectResult = Meteor.call('catalyst/projects')
#    console.log('projectResult', projectResult)
    asset = Meteor.call('catalyst/assets/upload', data)
    console.log 'asset', asset
    console.log 'asset id', asset.id
    data = Meteor.call('catalyst/assets/download', asset.id)
    console.log 'data', data
#    asset
