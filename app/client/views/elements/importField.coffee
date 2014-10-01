Template.importField.created = ->
  @data ?= {}

# TODO(aramk) Make this logic with a Meteor Dependency somehow?
Template.importField.rendered = ->
  name = @data.name
  filename = @data.filename

  $valueInput = $('[name="' + name + '"]')
  $filenameInput = $('[name="' + filename + '"]')
  if $valueInput.length == 0
    throw new Error('No input found with name ' + name)
  if $filenameInput.length == 0
    throw new Error('No input found with name ' + filename)

  $fileInput = @$('input')
  $removeButton = @$('.remove.button')
  $filename = @$('.filename')

  updateState = ->
    value = $valueInput.val()
    filename = $filenameInput.val()
    $fileInput[if !value then 'show' else 'hide'](0)
    $removeButton[if value then 'show' else 'hide'](0)
    $filename[if filename then 'show' else 'hide'](0)
    $filename.text(filename)

  updateState()
  $valueInput.change(updateState)
  $filenameInput.change(updateState)

  $removeButton.click ->
    $valueInput.val('')
    $fileInput.val('')
    $filenameInput.val('')
    updateState()
