Meteor.startup ->

  close = ->
    unless Router.getCurrentName() == 'design'
      Router.goToLastPath() or Router.go('projects')

  Form = Forms.defineModelForm
    name: 'projectForm'
    collection: 'Projects'
    onRender: -> updateFields.call(@)
    onSuccess: close
    onCancel: close

  updateFields = ->
    doc = @data.doc
    # TODO(aramk) Refactor with Typology form. No select fields are used at the moment.
    for key, input of @schemaInputs
      $input = $(input.node)
      fieldSchema = input.field
      isParamField = ParamUtils.hasPrefix(key)
      paramName = ParamUtils.removePrefix(key)

      defaultValue = null
      if isParamField
        defaultValue = fieldSchema.classes?.ALL?.defaultValue
      else
        # Regular field - not a parameter.
        defaultValue = fieldSchema.defaultValue

      # Add placeholders for default values
      if defaultValue?
        $input.attr('placeholder', defaultValue)

      # Select default values for dropdowns.
      if isSelectInput($input)
        if defaultValue?
          # Label which option is the default value.
          $defaultOption = getSelectOption(defaultValue, $input)
          if $defaultOption.length > 0
            $defaultOption.text($defaultOption.text() + ' (Default)')
        inputValue = SchemaUtils.getParameterValue(doc, paramName) if doc
        unless inputValue?
          inputValue = defaultValue ? ''
          setSelectValue($input, inputValue)

  Form.helpers
    project: -> Projects.getCurrentId()
    railTypes: -> Typologies.getRailTypeItems()

  Form.events
    'click .button.view-current': (e, template) ->
      AtlasManager.getCurrentCamera
        callback: (camera) ->
          stats = camera.getStats()
          setLocationField = (name, value) ->
            $(Forms.findFieldInput(template, name)).val(value)
          setLocationField 'parameters.location.lat', stats.position.latitude
          setLocationField 'parameters.location.lng', stats.position.longitude
          setLocationField 'parameters.location.cam_elev', stats.position.elevation
    'click .button.view-apply': (e, template) ->
      AtlasManager.getCurrentCamera
        callback: (camera) ->
          getFieldValue = (name) ->
            value = $(Forms.findFieldInput(template, name)).val()
            if value.trim() != '' then parseFloat(value) else null
          position =
            latitude: getFieldValue 'parameters.location.lat'
            longitude: getFieldValue 'parameters.location.lng'
            elevation: getFieldValue 'parameters.location.cam_elev'
          if position.latitude? && position.longitude? && position.elevation?
            camera.setPosition(position)
          else
            console.error('Cannot change camera position - must provide longitude, latitude and elevation',
              position)

isDropdown = ($input) -> $input.parent().hasClass('dropdown')
isSelectInput = ($input) -> isDropdown($input) || $input.is('select')
getSelectOption = (value, $input) ->
  if isDropdown($input)
    Template.dropdown.getItem($input.parent(), value)
  else
    $('option[value="' + value + '"]', $input)
setSelectValue = ($input, value) ->
  if isDropdown($input)
    Template.dropdown.setValue($input.parent(), value)
  else
    $input.val(value)
