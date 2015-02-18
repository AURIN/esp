Meteor.startup ->

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: Collections.createTemporary()
    onRender: ->
      template = @
      data = @data ? {}
      isLoading = false
      setLoadingState = (loading) ->
        if loading != isLoading
          $submit = template.$('.submit')
          $submit.toggleClass('disabled', loading)
          $submit.prop('disabled', loading)
          Template.loader.setActive(template.find('.loader'), loading)
          isLoading = loading
      $dropzone = template.$('.dropzone')
      dropzone = new Dropzone $dropzone[0],
        url: '/assets/upload'
        dictDefaultMessage: 'Drop a file here or click to upload.'
        addRemoveLinks: false
      dropzone.on 'sending', -> setLoadingState(true)
      dropzone.on 'error', (file, err) ->
        console.error 'Uploading assets failed', err
        setLoadingState(false)
      dropzone.on 'success', (file, result) ->
        console.log('Successful dropdown upload', arguments)
        format = 'shp'
        onSuccess = ->
          setLoadingState(false)
          data.settings?.onSuccess()
        assetId = result.id
        loadAssets = {}
        loadAssets[assetId] = format
        Meteor.call 'assets/load', {assets: loadAssets}, (err, result) ->
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
              isLayer: data.isLayer
            }).then((lotIds) ->
              LotUtils.renderAllAndZoom()
              onSuccess?()
            ).fin -> setLoadingState(false)

      dropzone.on 'error', (file, errorMessage) ->
        console.error('Error uploading file', arguments)
