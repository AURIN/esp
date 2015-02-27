# Change this to perform importing on the client for testing.
USE_SERVER = true

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
        unless result
          onError(file)
          return
        console.log('Successful dropdown upload', arguments)
        filename = file.name
        assetArgs = {
          c3mls: result.c3mls
          projectId: Projects.getCurrentId()
          filename: filename
        }
        onSuccess = ->
          data.settings?.onSuccess()
          LotUtils.renderAllAndZoom()
        onFinish = ->
          setLoadingState(false)
        handleImport(assetArgs, USE_SERVER).then(onSuccess).fin(onFinish).done()

      dropzone.on 'error', (file, errorMessage) ->
        console.error('Error uploading file', arguments)

handleImport = (assetArgs, useServer) ->
  if useServer then handleImportServer(assetArgs) else handleImportClient(assetArgs)

handleImportServer = (assetArgs) ->
  df = Q.defer()
  Meteor.call 'lots/from/asset', assetArgs, (err, result) ->
    if err then df.reject(err) else df.resolve()
  df.promise

handleImportClient = (assetArgs) -> LotUtils.fromAsset(assetArgs)
