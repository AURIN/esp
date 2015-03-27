# TODO(aramk) Remove this - only for testing

fs = Meteor.require('fs')

FileUtils.getFileSystemList = ->
  path = Files.primaryStore.path
  console.log('path', path)
  files = fs.readdirSync(path)
  console.log('files', files)
  files
