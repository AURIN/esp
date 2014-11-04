Meteor.startup ->

  collection = Typologies
  subclasses = Collections.createTemporary()

  updateFields = ->
    # Used to store original copies of DOM nodes which we modify based on the typology class.
    origInputs = @origInputs
    unless @origInputs
      origInputs = @origInputs = {}
    # TODO(aramk) Refactor with entityForm.
    typologyClass = Template.dropdown.getValue(getClassInput(@))
    # Only show fields when a class is selected.
    @$('.fields').toggle(!!typologyClass)
    defaultParams = Typologies.getDefaultParameterValues(typologyClass)
    console.debug 'updateFields', @, arguments, typologyClass
    $paramInputs = []
    $wrappers = {show: [], hide: []}
    for key, input of Forms.getSchemaInputs(@, collection)
      fieldSchema = input.field
      isParamField = ParamUtils.hasPrefix(key)
      paramName = ParamUtils.removePrefix(key) if isParamField
      classes = fieldSchema.classes
      classOptions = classes?[typologyClass]
      allClassOptions = classes?.ALL
      if allClassOptions?
        classOptions = _.extend(allClassOptions, classOptions)
      isHiddenField = classes and not classOptions

      $input = $(input.node)
      $label = @$('label[for="' + key + '"]')
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      $wrappers[if isHiddenField then 'hide' else 'show'].push($wrapper)
      # Hide fields which have classes specified which don't contain the current class.
      # $wrapper[if isHiddenField then 'hide' else 'show']()

      if isParamField
        defaultValue = Typologies.getParameter(defaultParams, key)
      else
        # Regular field - not a parameter.
        defaultValue = fieldSchema.defaultValue

      # Add placeholders for default values
      if defaultValue?
        $input.attr('placeholder', defaultValue)

      Forms.addRequiredLabel($label) if classOptions?.optional == false

      continue unless isParamField

      if $input.is('select')
        origInput = origInputs[key]
        if origInput
          # This field has been modified before - replace with a clone of the original.
          $origInput = origInputs[key].clone(true)
          $input.replaceWith($origInput)
          $origInput.val($input.val())
          $input = $origInput
        else
          # The field is in its original state - store a clone.
          origInputs[key] = $input.clone(true)

        if defaultValue?
          # Label which option is the default value.
          $defaultOption = getSelectOption(defaultValue, $input)
          if $defaultOption.length > 0
            $defaultOption.text($defaultOption.text() + ' (Default)')
        else
          # TODO(aramk) This is not available if a default value exists, since we cannot
          # override with null yet. It is available only if a value is not set.
          $option = $('<option value="">None</option>')
          $input.prepend($option)
        typology = @data.doc
        inputValue = Typologies.getParameter(typology, paramName) if typology
        unless inputValue?
          if defaultValue?
            $input.val(defaultValue)
          else
            $input.val('')
      # Avoid triggering a change event on the class input, which will trigger this method.
      $paramInputs.push($input) unless key == 'parameters.general.class'
    
    getVisibility = ($inputs) ->
      visible = []
      hidden = []
      _.each $inputs, ($input) -> (if $input.is(':visible') then visible else hidden).push($input)
      {visible: visible, hidden: hidden}

    markVisibility = ($inputs) -> _.each $inputs, ($input) ->
      $input.data('visibleBeforeChanges', $input.is(':visible'))
    
    # visiblityBeforeChanges = getVisibility($wrappers)
    _.each ['show', 'hide'], (visibility) -> _.each $wrappers[visibility], ($w) -> $w[visibility]()
    # Trigger changes in all fields so change event handlers are called.
    _.each $paramInputs, ($input) -> $input.trigger('change')
    # visiblityAfterChanges = getVisibility($wrappers)
    # Hide fields unavailable for this class. Perform this after the change handlers are called
    # to ensure they don't show inputs that should be hidden.
    #_.each ['show', 'hide'], (visibility) -> _.each $wrappers[visibility], ($w) -> $w[visibility]()
        # $w[visibility]() unless $w.data('visibleBeforeChanges') && !$w.is('visible')
    _.each $wrappers.hide, ($w) -> $w.hide()
    # Populate available subclasses.
    Collections.removeAllDocs(subclasses)
    _.each Typologies.getSubclassItems(typologyClass), (item) -> subclasses.insert(item)
    # Toggle visibility of geometry inputs.
    geom2dClasses = SchemaUtils.getField('parameters.space.geom_2d', Typologies).classes
    @$('.geom').toggle(!!geom2dClasses[typologyClass])
    # Toggle visibility of azimuth array inputs.
    azimuthClasses = SchemaUtils.getField('parameters.orientation.azimuth', Typologies).classes
    @$('.azimuth-array').toggle(!!azimuthClasses[typologyClass])

  bindEvents = ->
    # Bind change events to azimuth fields.
    onAzimuthChange = _.debounce (=> Form.updateAzimuthArray(@)), 300
    @$('.azimuth-array input').add(getAzimuthInput(@)).add(getCfaInput(@))
      .on('change keyup', onAzimuthChange)
    # onAzimuthChange()
    # Bind event to build quality dropdown
    onBuildQualityChange = => Form.updateBuildQuality(@)
    getBuildQualitySelect(@).on('change', onBuildQualityChange)
    # onBuildQualityChange()

  Form = Forms.defineModelForm
    name: 'typologyForm'
    collection: collection
    onRender: ->
      bindEvents.call(@)
      updateFields.call(@)
      $classInput = getClassInput(@)
      $classInput.on 'change', => updateFields.call(@)
      # Set values for azimuth fields.
      # TODO(aramk) Remove this with newer versions of Autoform.
      items = Form.getAzimuthItems(@)
      heating = items.heating
      cooling = items.cooling
      Template.azimuthArray.setValue(heating.$input, heating.value)
      Template.azimuthArray.setValue(cooling.$input, cooling.value)
    hooks:
      formToDoc: (doc) ->
        doc.project = Projects.getCurrentId()
        doc
      before:
        update: (docId, modifier, template) ->
          classParamId = 'parameters.general.class'
          newClass = modifier.$set[classParamId]
          if newClass
            oldTypology = Typologies.findOne(docId)
            oldClass = Typologies.getParameter(oldTypology, classParamId)
            if newClass != oldClass
              lots = Lots.findByTypology(docId)
              lotCount = lots.length
              if lotCount > 0
                lotNames = (_.map lots, (lot) -> lot.name).join(', ')
                alert('These Lots are using this Typology: ' + lotNames + '. Remove this Typology' +
                  ' from the Lot first before changing its class.')
                @result(false)
          # TODO(aramk) Due to a bug this is disabled for now.
          #                result = confirm(lotCount + ' ' + Strings.pluralize('Lot', lotCount) + ' will' +
          #                  ' have their classes changed from ' + oldClass + ' to ' + newClass +
          #                  ' to support this Typology. Do you wish to proceed?')
          #                # Updating the actual Lot is handled by the collection.
          #                @result(if result then modifier else false)
          modifier

  Form.helpers
    classes: -> Typologies.getClassItems()
    subclasses: -> subclasses
    classValue: -> @doc?.parameters?.general?.class
    subclassValue: -> @doc?.parameters?.general?.subclass

  Form.events
    'change [data-name="parameters.space.geom_2d"] input': (e, template) ->
      importFieldHandler(e, template, ['shp'])
    'change [data-name="parameters.space.geom_3d"] input': (e, template) ->
      importFieldHandler(e, template, ['kmz'])

  # AZIMUTH ARRAY
  
  Form.updateAzimuthArray = (template) ->
    items = Form.getAzimuthItems(template)
    heating = items.heating
    cooling = items.cooling
    azimuth = parseFloat(getAzimuthInput(template).val()) || 0
    $cfa = items.cfa.$cfa
    cfa = if $cfa? then parseFloat($cfa.val()) else items.cfa.value
    _.each [heating, cooling], (item) ->
      $input = item.$input
      $output = item.$output
      array = Template.azimuthArray.getValueArray($input)
      hasNullValue = _.some array, (value) -> value == null
      if !hasNullValue && cfa? && !isNaN(cfa)
        energyM2 = Template.azimuthArray.getOutputFromAzimuth(item.$input, azimuth)
      $output.parent().toggle(!energyM2?)
      if energyM2
        outputValue = energyM2 * cfa
        $output.val(outputValue) if outputValue?

  Form.getAzimuthItems = (template) ->
    parameters = template.data.doc?.parameters ? {}
    eq_azmth_h = parameters.orientation?.eq_azmth_h
    eq_azmth_c = parameters.orientation?.eq_azmth_c
    cfa = parameters.space?.cfa
    $heating = template.$('[data-name="parameters.orientation.eq_azmth_h"]')
    $cooling = template.$('[data-name="parameters.orientation.eq_azmth_c"]')
    $heatingOutput = template.$('[name="parameters.energy_demand.en_heat"]')
    $coolingOutput = template.$('[name="parameters.energy_demand.en_cool"]')
    $cfa = getCfaInput(template)
    {
      cfa: {value: cfa, $cfa: $cfa}
      heating: {value: eq_azmth_h, $input: $heating, $output: $heatingOutput}
      cooling: {value: eq_azmth_c, $input: $cooling, $output: $coolingOutput}
    }

  getAzimuthInput = (template) -> template.$('[name="parameters.orientation.azimuth"]')
  getCfaInput = (template) -> template.$('[name="parameters.space.cfa"]')

  # BUILD QUALITY

  Form.updateBuildQuality = (template) ->
    buildQuality = getBuildQualityValue(template)
    # subclass = getSubclassValue(template)
    # buildQualityParamId = Typologies.buildQualityMap[buildQuality]?[subclass]
    # getCostOfConstructionInput(template).parent().toggle(!buildQualityParamId?)
    getCostOfConstructionInput(template).parent().toggle(buildQuality == 'Custom')

  getClassInput = (template) -> template.$('[name="parameters.general.class"]').closest('.dropdown')
  getSelectOption = (value, $select) -> $('option[value="' + value + '"]', $select)
  getSubclassSelect = (template) ->
    template.$('[name="parameters.general.subclass"]').closest('.dropdown')
  getSubclassValue = (template) -> Template.dropdown.getValue(getSubclassSelect(template))
  getBuildQualitySelect = (template) -> template.$('[name="parameters.financial.build_quality"]')
  getBuildQualityValue = (template) -> getBuildQualitySelect(template).val()
  getCostOfConstructionInput = (template) -> template.$('[name="parameters.financial.cost_con"]')

  # UPLOADING

  importFieldHandler = (e, template, acceptedFormats) ->
    fileNode = e.target
    file = fileNode.files[0]
    unless file
      throw new Error('No file selected for uploading')
    mimeType = file.type
    format = _.find Assets.formats, (format) -> format.mimeType == mimeType
    unless format
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
        (fileObj) -> onUpload(fileObj, formatId, e, template).fin(onUploadComplete)
        onUploadComplete
      )
    else
      console.error('File did not match expected format', file, format, acceptedFormats)

  onUpload = (fileObj, format, e, template) ->
    console.debug 'uploaded', fileObj
    df = Q.defer()
    fileId = fileObj._id
    Assets.toC3ml(fileId, {format: format}).then(
      (result) ->
        c3mls = result.c3mls
        isPolygon = (c3ml) -> c3ml.type == 'polygon'
        isCollection = (c3ml) -> c3ml.type == 'collection'
        uploadIsPolygon = _.every c3mls, (c3ml) -> isPolygon(c3ml) || isCollection(c3ml)
        if uploadIsPolygon
          c3mlPolygon = _.find c3mls, (c3ml) -> isPolygon(c3ml)
          unless c3mlPolygon
            throw new Error('No suitable geometries or meshes found in file.')
          handleFootprintUpload(c3mlPolygon, fileObj, template).then(df.resolve, df.reject)
        else
          uploadNotEmpty = _.some c3mls, (c3ml) -> !isCollection(c3ml)
          unless uploadNotEmpty
            throw new Error('File must contain at least one c3ml entity other than a collection.')
          handleMeshUpload(c3mls, fileObj, template).then(df.resolve, df.reject)
      (err) -> df.reject(err)
    )
    df.promise

  handleFootprintUpload = (c3ml, fileObj, template) ->
    filename = fileObj.data.blob.name
    $geom2dInput = $(template.find('[name="parameters.space.geom_2d"]'))
    $geom2dFilenameInput = $(template.find('[name="parameters.space.geom_2d_filename"]'))
    WKT.fromC3ml(c3ml).then (wkt) ->
      # Trigger change to ensure importField controls are updated.
      $geom2dInput.val(wkt)
      $geom2dFilenameInput.val(filename).trigger('change')

  handleMeshUpload = (c3mls, fileObj, template) ->
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
