# Change this to perform importing on the client for testing.
USE_SERVER = true

Meteor.startup ->

  # Handles importing Lots when populating a project with precinct data.

  Form = Forms.defineModelForm
    name: 'importForm'
    collection: Collections.createTemporary()
    onRender: ->
      template = @
      data = @data ? {}
      isLoading = false
      isLayer = data.isLayer ? false
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
      dropzone.on 'addedfile', ->
        if !isLayer && Lots.findByProject().count() > 0
          result = window.confirm('Are you sure you want to replace the existing Lots in ' + 
              'the project?')
          unless result
            throw new Error('Lots upload cancelled')
      dropzone.on 'sending', (file, xhr, formData) ->
        setLoadingState(true)
        formData.append('merge', isLayer)
      dropzone.on 'error', (file, err) ->
        Logger.error 'Uploading assets failed', err
        setLoadingState(false)
      dropzone.on 'success', (file, result) ->
        unless result
          onError(file)
          return
        Logger.info('Successful dropdown upload', arguments)
        filename = file.name
        assetArgs = {
          c3mls: result.c3mls
          projectId: Projects.getCurrentId()
          isLayer: isLayer
          filename: filename
        }
        onSuccess = ->
          data.settings?.onSuccess()
          PubSub.publish 'entities/reload', -> PubSub.publish('entities/reactive-render', true)
        onFinish = ->
          setLoadingState(false)
        onError = (err) ->
          Logger.error(err)
          PubSub.publish('entities/reactive-render', true)
        # Disable reactive rendering to avoid excessive rendering while importing.
        PubSub.publish('entities/reactive-render', false)
        handleImport(assetArgs, USE_SERVER).then(onSuccess, onError).fin(onFinish).done()

      dropzone.on 'error', (file, errorMessage) ->
        Logger.error('Error uploading file', arguments)
  
  Form.helpers
    collectionName: -> if @isLayer then 'Footprints' else 'Lots'

handleImport = (assetArgs, useServer) ->
  if useServer then handleImportServer(assetArgs) else handleImportClient(assetArgs)

handleImportServer = (assetArgs) -> Promises.serverMethodCall 'lots/from/asset', assetArgs

handleImportClient = (assetArgs) -> LotUtils.fromAsset(assetArgs)
