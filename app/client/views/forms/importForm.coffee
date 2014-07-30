Meteor.startup ->

  Formats = Collections.createTemporary()

  # TODO(aramk) Change this to assets/formats/inputs.
  Meteor.call 'assets/formats', (err, result) ->
    console.log('formats', err, result)
    _.each result, (format) ->
      ext = format.extensions
      # TODO(aramk) Remove this filter to allow other types.
      if ext == 'shp'
        format.label = ext.toUpperCase()
        Formats.insert(format)
    console.log('formats', Formats.find().fetch())

  ImportedAssets = Collections.createTemporary()

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: ImportedAssets

  Form.helpers
    formats: -> Formats.find()
    defaultFormat: -> 'shp' #Formats.find({label: 'SHP'}).fetch()[0]

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
              onSynthesize = (response) ->
                body = response.body
                console.log 'synthesize', body.length
                c3mlId = body.c3mlId
                Meteor.call 'assets/c3ml/download', c3mlId, (err, c3mls) ->
                  if err
                    console.error 'c3ml download failed', err
                    return
                  # TODO(aramk) Download meta-data to get the names of the entities.
                  console.log('c3ml', c3mls.length)
                  # TODO(aramk) Handle error and pass back
                  LotUtils.fromC3ml c3mls, (lotIds) ->
                    console.log('lotIds', lotIds)
                    onSuccess?(lotIds)

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
                  assets = [result];
                  loadAssets = {}
                  for result in assets
                    loadAssets[assetId] = format
                  request =
                    loadAsset:
                      isForSynthesis: true
                      assets: loadAssets
                  console.log 'synthesize request', request
                  Meteor.call 'assets/synthesize', request, (err, result) ->
                    if err
                      console.error 'Asset synthesize failed', err
                      return
                    console.debug 'assets/synthesize', err, result
                    if result
                      onSynthesize(result)
                    else
                      console.error 'Synthesize failed', err

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


