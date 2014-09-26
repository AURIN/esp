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
          Files.upload(file).then (fileObj) ->
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
        Q.all(importDfs).then ->
          AtlasManager.zoomToProject()
          onSuccess?()
