Meteor.startup ->

  getFormats = (collection) ->
    Meteor.call 'assets/formats/input', (err, result) ->
      _.each result, (format) ->
        ext = format.extensions
        # TODO(aramk) Remove this filter to allow other types.
        if ext == 'shp'
          format.label = ext.toUpperCase()
          collection.insert(format)
    collection

#  importDfs = null

  ImportedAssets = Collections.createTemporary()

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: ImportedAssets

#  Form.rendered = ->
#    importDfs = []

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
      format = Template.dropdown.getValue(template.find('.dropdown.format'))
      setLoadingState = (loading) ->
        $submit = $(template.find('.submit'))
        $submit.toggleClass('disabled', loading)
        $submit.prop('disabled', loading)
        $dimmer = $(template.find('.dimmer'))
        $dimmer.toggleClass('active', loading)
      setLoadingState(true)
      onSuccess = ->
        setLoadingState(false)
        template.data?.settings?.onSuccess()
      importDfs = []
      console.debug 'files', files, 'format', format
      if files.length == 0
        console.log('Select a file to upload.')
      else
        # TODO(aramk) handle multiple files?
        _.each files, (file) ->
          importDf = Q.defer()
          importDfs.push(importDf.promise)
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
                        importDf.resolve(lotIds)

              timerHandler = ->
                progress = fileObj.uploadProgress()
                uploaded = fileObj.isUploaded()
                console.debug 'progress', progress, uploaded
                if uploaded
                  clearTimeout(handle)
                  onUpload()

              handle = setInterval timerHandler, 1000
        console.log('importDfs', importDfs)
        Q.all(importDfs).then ->
          AtlasManager.zoomToProject()
          onSuccess?()

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


