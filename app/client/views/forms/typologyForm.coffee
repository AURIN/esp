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
      $label = Forms.getInputLabel($input)
      $wrapper = $input.closest(Forms.FIELD_SELECTOR)
      $wrappers[if isHiddenField then 'hide' else 'show'].push($wrapper)
      # Hide fields which have classes specified which don't contain the current class.
      # $wrapper[if isHiddenField then 'hide' else 'show']()

      if isParamField
        defaultValue = SchemaUtils.getParameterValue(defaultParams, key)
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
        inputValue = SchemaUtils.getParameterValue(typology, paramName) if typology
        unless inputValue?
          if defaultValue?
            $input.val(defaultValue)
          else
            $input.val('')
      # Avoid triggering a change event on the class input, which will trigger this method.
      $paramInputs.push($input) unless key == 'parameters.general.class'

    _.each ['show', 'hide'], (visibility) -> _.each $wrappers[visibility], ($w) -> $w[visibility]()
    # Trigger changes in all fields so change event handlers are called. This assumes they are
    # synchronous.
    _.each $paramInputs, ($input) -> $input.trigger('change')
    # Hide fields unavailable for this class. Perform this after the change handlers are called
    # to ensure they don't show inputs that should be hidden.
    _.each $wrappers.hide, ($w) -> $w.hide()
    # Populate available subclasses.
    Collections.removeAllDocs(subclasses)
    _.each Typologies.getSubclassItems(typologyClass), (item) -> subclasses.insert(item)
    # Toggle visibility of geometry inputs.
    geom2dClasses = SchemaUtils.getField('parameters.space.geom_2d', Typologies).classes
    canModifyGeometry = !!geom2dClasses[typologyClass] && typologyClass != 'PATHWAY'
    @$('.geom').toggle(canModifyGeometry)
    # Toggle visibility of azimuth array inputs.
    azimuthClasses = SchemaUtils.getField('parameters.orientation.azimuth', Typologies).classes
    @$('.azimuth-array').toggle(!!azimuthClasses[typologyClass])

  bindEvents = ->
    # Bind change events to azimuth fields.
    onAzimuthChange = => Form.updateAzimuthArray(@)
    $azimuthFields = @$('.azimuth-array input').add(getAzimuthInput(@)).add(getCfaInput(@))
    $azimuthFields.on('change', onAzimuthChange)
    $azimuthFields.on('keyup', _.debounce(onAzimuthChange, 300))
    # Bind event to build quality dropdown
    onBuildQualityChange = => Form.updateBuildQuality(@)
    getBuildQualitySelect(@).on('change', onBuildQualityChange)

  Form = Forms.defineModelForm
    name: 'typologyForm'
    collection: collection
    onRender: ->
      bindEvents.call(@)
      updateFields.call(@)
      $classInput = getClassInput(@)
      $classInput.on 'change', => updateFields.call(@)
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
            oldClass = SchemaUtils.getParameterValue(oldTypology, classParamId)
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
      GeometryImportFields.importFieldHandler(e, template, ['shp'])
    'change [data-name="parameters.space.geom_3d"] input': (e, template) ->
      GeometryImportFields.importFieldHandler(e, template, ['kmz'])

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
