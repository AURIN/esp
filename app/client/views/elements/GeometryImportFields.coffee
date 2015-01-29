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
          hasPolygon = _.some c3mls, (c3ml) -> isPolygon(c3ml)
          unless hasPolygon
            throw new Error('File must contain at least one polygon.')
          paramId = 'geom_2d'
        else
          uploadNotEmpty = _.some c3mls, (c3ml) -> !isCollection(c3ml)
          unless uploadNotEmpty
            throw new Error('File must contain at least one geometry.')
          paramId = 'geom_3d'
        @handleUpload(c3mls, fileObj, paramId, template).then(df.resolve, df.reject)
      df.reject
    )
    df.promise

  handleUpload: (c3mls, fileObj, paramId, template) ->
    filename = fileObj.data.blob.name
    $geomInput = $(template.find('[name="parameters.space.' + paramId + '"]'))
    $geomFilenameInput = $(template.find('[name="parameters.space.' + paramId + '_filename"]'))
    # Upload the c3ml as a file.
    doc = {c3mls: c3mls}
    docString = JSON.stringify(doc)
    blob = new Blob([docString])
    Files.upload(blob).then (fileObj) ->
      id = fileObj._id
      $geomInput.val(id)
      $geomFilenameInput.val(filename).trigger('change')

