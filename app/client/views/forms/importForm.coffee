Meteor.startup ->

  getFormats = (collection) ->
    # TODO(aramk) Change this to assets/formats/inputs.
    Meteor.call 'assets/formats/input', (err, result) ->
      _.each result, (format) ->
        ext = format.extensions
        # TODO(aramk) Remove this filter to allow other types.
        if ext == 'shp'
          format.label = ext.toUpperCase()
          collection.insert(format)
    collection

  ImportedAssets = Collections.createTemporary()

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: ImportedAssets

  Form.helpers
    formats: ->
      formats = Collections.createTemporary()
      getFormats(formats)
      formats.find()
    defaultFormat: -> 'shp'

  Form.events
    'submit form': (e, template) ->
      e.preventDefault()
      fileNode = template.find('form input[type="file"]');
      files = fileNode.files
      format = $(template.find('.dropdown.format')).dropdown('get value')
      onSuccess = template.data?.settings?.onSuccess
      console.debug 'files', files, 'format', format
      if files.length == 0
        console.log('Select a file to upload.')
      else
        # TODO(aramk) handle multiple files?
        _.each files, (file) ->
          # TODO(aramk) Abstract into Files.upload.
          Files.insert file, (err, fileObj) ->
            console.debug 'Files.insert', arguments
            if err
              console.error(err.toString())
            else
              # TODO(aramk) Remove timeout and use an event callback.
              onUpload = ->
                console.debug 'uploaded', fileObj
                fileId = fileObj._id
                Meteor.call 'assets/import', fileId, (err, result) ->
                  if err
                    console.error 'Asset import failed', err, fileObj
                    return
                  console.log 'asset', result
                  assetId = result.id
                  loadAssets = {}
                  loadAssets[assetId] = format
                  Meteor.call 'assets/load', loadAssets, (err, result) ->
                    if err
                      console.error 'Loading assets failed', loadAssets, err
                      return
                    else
                      body = result.body
                      # Use geoBlobId instead of original assetId to ensure IDs in the c3ml match
                      # those in the parameter response.
                      LotUtils.fromAsset({
                        assetId: body.geoBlobId
                        c3mlId: body.c3mlId
                        metaDataId: body.metaDataId
                      }).then (lotIds) ->
                        console.log('lotIds', lotIds)
                        onSuccess?(lotIds)

              timerHandler = ->
                progress = fileObj.uploadProgress()
                uploaded = fileObj.isUploaded()
                console.debug 'progress', progress, uploaded
                if uploaded
                  clearTimeout(handle)
                  onUpload()

              handle = setInterval timerHandler, 1000

# TODO(aramk) Integrate dropzone.
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


