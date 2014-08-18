Meteor.startup ->

  getClassInput = ->
    $(@.find('[name="parameters.general.class"]')).closest('.dropdown')

  getClassInputValue = ->
    getClassInput.call(@).dropdown('get value')

  updateFields = ->
    typology = @data.doc
    typologyClass = getClassInputValue.call(@)
    console.debug 'updateFields', @, arguments, typologyClass
    for key, input of @schemaInputs
      classes = input.field.classes
      classOptions = if classes and typologyClass then classes[typologyClass] else null
      paramName = key.replace(/^parameters\./, '')
      $input = $(input.node)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      if classOptions
        # Add placeholders for default values
        $input.attr('placeholder', classOptions.defaultValue)
      # Hide fields which have classes specified which don't contain the current class.
      $wrapper[if classes and not classOptions then 'hide' else 'show']()
      # Add a "none" option to select fields.
      if $input.is('select')
        $option = $('<option value="">None</option>')
        $input.prepend($option)
        inputValue = if typology then Typologies.getParameter(typology, paramName) else null
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
        if ext == 'shp'
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

  # The current footprint GeoEntity.
  currentFootprint = null

  Form.events
    'click .footprint-import .submit.button': (e, template) ->
      # TODO(aramk) Abstract this into a simple import widget. Reuse in import form.
      $footprintImport = $(template.find('.footprint-import'))
      fileNode = $('input[type="file"]', $footprintImport)[0]
      files = fileNode.files
      format = $('.dropdown.format', $footprintImport).dropdown('get value')
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
              # TODO(aramk) Remove timeout and use an event callback.
              onUpload = ->
                console.debug 'uploaded', fileObj
                fileId = fileObj._id
                WKT.fromFile(fileId, {format: format}).then (wktResults) ->
                  console.log('wktResults', wktResults)
              timerHandler = ->
                progress = fileObj.uploadProgress()
                uploaded = fileObj.isUploaded()
                console.debug 'progress', progress, uploaded
                if uploaded
                  clearTimeout(handle)
                  onUpload()
              handle = setInterval timerHandler, 1000
