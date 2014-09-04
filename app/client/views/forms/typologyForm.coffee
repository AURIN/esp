Meteor.startup ->

  getClassInput = ->
    $(@.find('[name="parameters.general.class"]')).closest('.dropdown')

  updateFields = ->
    # TODO(aramk) Refactor with entityForm.
    typology = @data.doc
    typologyClass = Template.dropdown.getValue(getClassInput.call(@))
    defaultParams = Typologies.getDefaultParameterValues(typologyClass)
    console.debug 'updateFields', @, arguments, typologyClass
    for key, input of @schemaInputs
      fieldSchema = input.field
      isParamField = ParamUtils.hasPrefix(key)
      isSelectField = !!fieldSchema.allowedValues
      paramName = ParamUtils.removePrefix(key) if isParamField
      classes = fieldSchema.classes
      classOptions = classes?[typologyClass]
      allClassOptions = classes?.ALL
      if allClassOptions?
        classOptions = _.extend(allClassOptions, classOptions)

      # Add placeholders for default values
      if isParamField
        defaultValue = Typologies.getParameter(defaultParams, key)
      else
        # Regular field - not a parameter.
        defaultValue = fieldSchema.defaultValue

      $input = $(input.node)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      if defaultValue?
        if isSelectField
          # TODO(aramk) Setting value for dropdowns doesn't work - autoform might be setting it
          # after render?
          setSelectValue = ($select, value) ->
            ->
              console.log($select, value)
              $select.val(value)
          setTimeout(
            setSelectValue($input, defaultValue)
            1000
          )
#          $('option[value="' + defaultValue + '"]', $input).attr('selected', 'selected')
        else
          $input.attr('placeholder', defaultValue)

      # Hide fields which have classes specified which don't contain the current class.
      $wrapper[if classes and not classOptions then 'hide' else 'show']()
      # Add a "none" option to select fields.
      if $input.is('select')
        $option = $('<option value="">None</option>')
        $input.prepend($option)
        inputValue = null
        if typology && isParamField
          inputValue = Typologies.getParameter(typology, paramName)
        unless inputValue?
          $input.val('')

  Form = Forms.defineModelForm
    name: 'typologyForm'
    collection: 'Typologies'
    onRender: ->
      updateFields.call(@)
      $classInput = getClassInput.call(@)
      $classInput.on 'change', => updateFields.call(@)
    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc

  # TODO(aramk) Refactor with import form.
  getFormats = (collection) ->
    Meteor.call 'assets/formats/input', (err, result) ->
      _.each result, (format) ->
        ext = format.extensions
        # TODO(aramk) Remove this filter to allow other types.
        if ext == 'shp' || ext == 'kmz'
          format.label = ext.toUpperCase()
          collection.insert(format)
    collection

  Form.helpers
    classes: -> Typologies.getClassItems()
    classValue: -> @doc?.parameters?.general?.class
  # TODO(aramk) Refactor with import form.
    formats: ->
      formats = Collections.createTemporary()
      getFormats(formats)
      formats.find()
    defaultFormat: -> 'shp'

  onUpload = (fileObj, format, template) ->
    console.debug 'uploaded', fileObj
    fileId = fileObj._id
    Assets.toC3ml(fileId, {format: format}).then (result) ->
      c3mls = result.c3mls
      isPolygon = (c3ml) -> c3ml.type == 'polygon'
      isCollection = (c3ml) -> c3ml.type == 'collection'
      uploadIsPolygon = _.every c3mls, (c3ml) -> isPolygon(c3ml) || isCollection(c3ml)
      if uploadIsPolygon
        c3mlPolygon = _.find c3mls, (c3ml) -> isPolygon(c3ml)
        unless c3mlPolygon
          throw new Error('No suitable geometries or meshes found in file.')
        handleFootprintUpload(c3mlPolygon, template)
      else
        uploadNotEmpty = _.some c3mls, (c3ml) -> !isCollection(c3ml)
        unless uploadNotEmpty
          throw new Error('File must contain at least one c3ml entity other than a collection.')
        handleMeshUpload(c3mls, template)

  handleFootprintUpload = (c3ml, template) ->
    $geomInput = $(template.find('[name="parameters.space.geom_2d"]'))
    WKT.fromC3ml(c3ml).then (wkt) ->
      $geomInput.val(wkt)

  handleMeshUpload = (c3mls, template) ->
    $meshInput = $(template.find('[name="parameters.space.geom_3d"]'))
    # Upload the c3ml as a file.
    doc = {c3mls: c3mls}
    docString = JSON.stringify(doc)
    #    buffer = ArrayBuffers.stringToBufferArray(docString)
    blob = new Blob([docString])
    # TODO(aramk) Abstract into Files.upload.
    Files.insert blob, (err, fileObj) ->
      console.debug 'Files.insert', arguments
      if err
        console.error(err.toString())
      # TODO(aramk) Remove timeout and use an event callback.
      timerHandler = ->
        progress = fileObj.uploadProgress()
        uploaded = fileObj.isUploaded()
        console.debug 'progress', progress, uploaded
        if uploaded
          clearTimeout(handle)
          console.debug 'uploaded', fileObj
          id = fileObj._id
          $meshInput.val(id)
      #          Meteor.call 'files/download/string', fileObj._id, (err, data) ->
      #            console.debug 'download', arguments
      handle = setInterval timerHandler, 1000

  Form.events
    'click .footprint-import .submit.button': (e, template) ->
      # TODO(aramk) Abstract this into a simple import widget. Reuse in import form.
      $footprintImport = $(template.find('.footprint-import'))
      fileNode = $('input[type="file"]', $footprintImport)[0]
      files = fileNode.files
      format = Template.dropdown.getValue($('.dropdown.format', $footprintImport))
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
              # TODO(aramk) Remove timeout and use an event callback.
              timerHandler = ->
                progress = fileObj.uploadProgress()
                uploaded = fileObj.isUploaded()
                console.debug 'progress', progress, uploaded
                if uploaded
                  clearTimeout(handle)
                  onUpload(fileObj, format, template)
              handle = setInterval timerHandler, 1000
