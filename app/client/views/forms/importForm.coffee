Meteor.startup ->

  Formats = Collections.createTemporary()

  Meteor.call 'assets/formats', (err, result) ->
    console.log('formats', err, result)
    _.each result, (format) ->
      format.label = format.extensions.toUpperCase()
      Formats.insert(format)
    console.log('formats', Formats.find().fetch())

  ImportedAssets = Collections.createTemporary()

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: ImportedAssets

  Form.helpers
    formats: -> Formats.find()

  Form.events
    'submit form': (e, template) ->
      e.preventDefault()
      fileNode = template.find('form input[type="file"]');
      files = fileNode.files
      format = $(template.find('.dropdown.format')).dropdown('get value')
      console.debug 'files', files, 'format', format
      if files.length == 0
        console.log('Select a file to upload.')
      else
        # TODO(aramk) handle multiple files?
        _.each files, (file) ->
          Files.insert file, (err, fileObj) ->
            console.debug 'Files.insert', arguments
            if err
              console.error(err.toString())
            else
              # TODO(aramk) Remove timeout and use an event callback.
              handler = ->
                progress = fileObj.uploadProgress()
                uploaded = fileObj.isUploaded()
                console.debug 'progress', progress, uploaded
                if uploaded
                  clearTimeout(handle)
                  console.log('Upload complete')
                  Meteor.call 'assets/import', fileObj._id, (err, result) ->
                    if err
                      console.error(err)
                    else
                      console.log 'result', result
                      assets = [result];
                      loadAssets = {}
                      for asset in assets
                        loadAssets[asset.id] = format
                      request = {
                        loadAsset: {
                          isForSynthesis: true,
                          assets: loadAssets
                        }
                      }
                      console.log 'synthesize', request
                      Meteor.call 'assets/synthesize', request, (err, result) ->
                        if err
                          console.error('Synthesize failed', err)
                        else
                          jobId = result.jobId
                          console.debug('job id', jobId)
                          new Poll().pollJob(jobId).then(
                            (job) ->
                              console.log 'job', job
                              body = job.body
                              Meteor.call 'assets/c3ml/download', body.c3mlId, (err, c3ml) ->
                                console.log('c3ml', c3ml)
                                atlas = AtlasManager.getInstance()
                                console.log('atlas', atlas)
                                atlas.publish('entity/show/bulk', {features: c3ml});
                            (err) ->
                              console.error 'Job failed', err
                          )


              handle = setInterval handler, 1000

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


