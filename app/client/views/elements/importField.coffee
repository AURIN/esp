Template.importField.created = ->
  @data ?= {}

# TODO(aramk) Make this logic with a Meteor Dependency somehow?
Template.importField.rendered = ->
  name = @data.name

  $valueInput = $('[name="' + name + '"]')
  if $valueInput.length == 0
    throw new Error('No input found with name ' + name)

  $fileInput = $(@find('input'))
  $removeButton = $(@find('.remove.button'))

  updateState = ->
    value = $valueInput.val()
    $fileInput[if !value then 'show' else 'hide'](0)
    $removeButton[if value then 'show' else 'hide'](0)

  updateState()
  $valueInput.change(updateState)

  $removeButton.click ->
    $valueInput.val('')
    $fileInput.val('')
    updateState()
