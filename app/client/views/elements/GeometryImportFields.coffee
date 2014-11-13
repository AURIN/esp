@GeometryImportFields =

  importFieldHandler: (e, template, acceptedFormats) ->
    fileNode = e.target
    $fileNode = $(fileNode)
    file = fileNode.files[0]
    unless file
      throw new Error('No file selected for uploading')
    mimeType = file.type
    format = _.find Assets.formats, (format) -> format.mimeType == mimeType
    unless format
      $fileNode.val(null)
      throw new Error('Format not recognised for mime-type: ' + file.type)
    formatId = format.id
    if _.indexOf(acceptedFormats, formatId) >= 0
      $submitButton = template.$('.submit.button')
      $loader = $(e.target).siblings('.ui.dimmer')
      setSubmitButtonDisabled = (disabled) ->
        $submitButton.toggleClass('disabled', disabled)
        $submitButton.prop('disabled', disabled)
      onUploadStart = ->
        $loader.addClass('active')
        setSubmitButtonDisabled(true)
      onUploadComplete = ->
        $loader.removeClass('active')
        setSubmitButtonDisabled(false)
      onUploadStart()
      Files.upload(file).then(
        (fileObj) => @onUpload(fileObj, formatId, e, template).fin(onUploadComplete)
        onUploadComplete
      )
    else
      console.error('File did not match expected format', file, format, acceptedFormats)
      $fileNode.val(null)

  onUpload: (fileObj, format, e, template) ->
    console.debug 'uploaded', fileObj
    df = Q.defer()
    fileId = fileObj._id
    Assets.toC3ml(fileId, {format: format}).then(
      (result) =>
        c3mls = result.c3mls
        isPolygon = (c3ml) -> c3ml.type == 'polygon'
        isCollection = (c3ml) -> c3ml.type == 'collection'
        uploadIsPolygon = _.every c3mls, (c3ml) -> isPolygon(c3ml) || isCollection(c3ml)
        if uploadIsPolygon
          c3mlPolygon = _.find c3mls, (c3ml) -> isPolygon(c3ml)
          unless c3mlPolygon
            throw new Error('No suitable geometries or meshes found in file.')
          @handleFootprintUpload(c3mlPolygon, fileObj, template).then(df.resolve, df.reject)
        else
          uploadNotEmpty = _.some c3mls, (c3ml) -> !isCollection(c3ml)
          unless uploadNotEmpty
            throw new Error('File must contain at least one c3ml entity other than a collection.')
          @handleMeshUpload(c3mls, fileObj, template).then(df.resolve, df.reject)
      (err) -> df.reject(err)
    )
    df.promise

  handleFootprintUpload: (c3ml, fileObj, template) ->
    filename = fileObj.data.blob.name
    $geom2dInput = $(template.find('[name="parameters.space.geom_2d"]'))
    $geom2dFilenameInput = $(template.find('[name="parameters.space.geom_2d_filename"]'))
    WKT.fromC3ml(c3ml).then (wkt) ->
      # Trigger change to ensure importField controls are updated.
      $geom2dInput.val(wkt)
      $geom2dFilenameInput.val(filename).trigger('change')

  handleMeshUpload: (c3mls, fileObj, template) ->
    filename = fileObj.data.blob.name
    $geom3dInput = $(template.find('[name="parameters.space.geom_3d"]'))
    $geom3dFilenameInput = $(template.find('[name="parameters.space.geom_3d_filename"]'))
    # Upload the c3ml as a file.
    doc = {c3mls: c3mls}
    docString = JSON.stringify(doc)
    blob = new Blob([docString])
    Files.upload(blob).then (fileObj) ->
      id = fileObj._id
      $geom3dInput.val(id)
      $geom3dFilenameInput.val(filename).trigger('change')

