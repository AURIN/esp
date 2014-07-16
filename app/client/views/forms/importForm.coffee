Meteor.startup ->

  ImportedAssets = Collections.createTemporary()

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: ImportedAssets

  Form.events
    'submit form': (e, template) ->
      e.preventDefault()
      fileNode = template.find('form input[type="file"]');
      files = fileNode.files
      console.debug 'files', files
      if files.length == 0
        console.log('Select a file to upload.')
      else
        _.each files, (file) ->
          Files.insert file, (err, fileObj) ->
            console.debug 'Files.insert', arguments
            if err
              console.error(err.toString())
            else

              Files.on 'stored', (fileObj, storeName) ->
                console.log('stored', arguments)
              Files.on 'uploaded', (fileObj, storeName) ->
                console.log('uploaded', arguments)

#              fileObj.on 'stored', ->
#                console.debug('stored', arguments)
              # TODO(aramk) Remove timeout and use an event callback.
              handler = ->
                progress = fileObj.uploadProgress()
                uploaded = fileObj.isUploaded()
                console.debug 'progress', progress, uploaded
                if uploaded
                  clearTimeout(handle)
                  console.log('Upload complete')
#                  Meteor.call 'customers/from/csv/file', fileObj._id, (error, customers) ->
#                    if error
#                      console.error(error)
#                    else
#                      console.log('Adding', customers.length, 'customers...')
#                    Meteor.call 'customers/import', customers, (error, result) ->
#                      if error
#                        console.error(error)
#                      else
#                        console.log('Imported', result, 'customers')
              handle = setInterval handler, 1000

#    onRender: ->
#      dropzoneNode = @.find('.dropzone')
#      dropzone = new Dropzone(dropzoneNode, {
#        dictDefaultMessage: 'Drop files here or click to upload.',
#        addRemoveLinks: true,
#        dictRemoveFile: 'Remove'
#      });
#
#      dropzone.on 'addedfile', (file) ->
#        console.debug 'addedfile', file
#
#      dropzone.on 'removedfile', (file) ->
#        console.debug 'removedfile', file
#
#      dropzone.on 'success', (file, result) ->
#        console.debug 'success', file, result
#
#      dropzone.on 'error', (file, errorMessage) ->
#        console.debug 'error', file, errorMessage


