TemplateClass = Template.azimuthArray

# TODO(aramk) Use this with the newer version of Autoform.
# AutoForm.addInputType('azimuthArray', {
#   '.azimuth-array': -> TemplateClass.getValue($(@))
#   template: 'azimuthArray'
#   valueIn: (value) ->
#     console.log 'valueIn', value
#   valueOut: ->
#     console.log 'valueOut', this
#     TemplateClass.getValue(this)
# })

# registerAutoForm = _.once ->
#   return if typeof AutoForm == 'undefined'
#   AutoForm.addInputType('azimuthArray', {
#     '.azimuth-array': -> TemplateClass.getValue($(@))
#   })

# TemplateClass.created = -> registerAutoForm()

AutoForm.inputValueHandlers
  '.azimuth-array': -> TemplateClass.getValue(this)

TemplateClass.rendered = ->
  name = @data.name
  schemaKey = @data.schemaKey
  throw new Error('Name required for dropdown.') unless name
  $input = @$('.azimuth-array')
  schemaKey = if schemaKey != undefined then schemaKey else true
  $input.attr('data-schema-key', name) if schemaKey

TemplateClass.getValue = (elem) ->
  array = []
  hasNonEmptyValue = false
  $('.values input', elem).each ->
    value = parseFloat($(@).val().trim())
    if isNaN(value)
      value = null
    else
      hasNonEmptyValue = true
    array.push(value)
  if hasNonEmptyValue then JSON.stringify(array) else ''

TemplateClass.getValueArray = (elem) ->
  array = TemplateClass.getValue(elem)
  if array != '' then JSON.parse(array) else null

# TODO(aramk) Use this for setting the custom value on the form element when loaded.
TemplateClass.setValue = (elem, value) ->
  return unless value
  try
    value = JSON.parse(value)
  catch e
    return
  $('.values input', elem).each ->
    $(this).val(value.shift())

TemplateClass.getOutputFromAzimuth = (elem, azimuth) ->
  array = TemplateClass.getValueArray(elem)
  return null unless array
  Typlogies.calcOutputFromAzimuth(array, azimuth)
