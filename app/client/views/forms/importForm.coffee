Meteor.startup ->

  ImportedAssets = Collections.createTemporary()

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: ImportedAssets
    onRender: ->
      dropzoneNode = @.find('.dropzone')
      dropzone = new Dropzone(dropzoneNode, {
        dictDefaultMessage: 'Drop files here or click to upload.',
        addRemoveLinks: true,
        dictRemoveFile: 'Remove'
      });

      dropzone.on 'addedfile', (file) ->
        console.debug 'addedfile', file

      dropzone.on 'removedfile', (file) ->
        console.debug 'removedfile', file

      dropzone.on 'success', (file, result) ->
        console.debug 'success', file, result

      dropzone.on 'error', (file, errorMessage) ->
        console.debug 'error', file, errorMessage
