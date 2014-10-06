Meteor.startup ->

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: Collections.createTemporary()
    onRender: ->
      template = @
      $dropzone = template.$('.dropzone')
      dropzone = new Dropzone $dropzone[0],
        url: '/assets/upload'
        dictDefaultMessage: 'Drop a file here or click to upload.'
        addRemoveLinks: false
      dropzone.on 'success', (file, result) ->
        console.log('Successful dropdown upload', arguments)
        format = 'shp'
        setLoadingState = (loading) ->
          $submit = $(template.find('.submit'))
          $submit.toggleClass('disabled', loading)
          $submit.prop('disabled', loading)
          Template.loader.setActive(template.find('.loader'), loading)
        setLoadingState(true)
        onSuccess = ->
          setLoadingState(false)
          template.data?.settings?.onSuccess()
        assetId = result.id
        loadAssets = {}
        loadAssets[assetId] = format
        Meteor.call 'assets/load', loadAssets, (err, result) ->
          if err
            console.error 'Loading assets failed', loadAssets, err
            setLoadingState(false)
          else
            body = result.body
            # Use geoBlobId instead of original assetId to ensure IDs in the c3ml match
            # those in the parameter response.
            LotUtils.fromAsset({
              assetId: body.geoBlobId
              c3mlId: body.c3mlId
              metaDataId: body.metaDataId
            }).then(
              (lotIds) ->
                LotUtils.renderAllAndZoom()
                onSuccess?()
              (err) ->
                console.error('Failed to import lots', err)
                setLoadingState(false)
            )

      dropzone.on 'error', (file, errorMessage) ->
        console.error('Error uploading file', arguments)
