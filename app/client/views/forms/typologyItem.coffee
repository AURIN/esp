formName = 'typologyItem'
collection = null
collectionName = null
TypologyTemplate = Template[formName]

# TODO(aramk) Provide callback in settings
onSuccess = ->
  Session.set('currentPanel', 'default')
onCancel = ->
  Session.set('currentPanel', 'default')

TypologyTemplate.created = ->
  @data ?= {}
  collection = Typologies
  collectionName = collection._name

TypologyTemplate.rendered = ->
  AutoForm.resetForm(formName)
  @data ?= {}

AutoForm.addHooks formName,
  onSuccess: (operation, result) ->
    AutoForm.resetForm(formName)
    onSuccess()

TypologyTemplate.helpers
  collection: -> collection
  formName: -> formName
  formType: -> if @doc then 'update' else 'insert'
  submitText: -> if @doc then 'Save' else 'Create'

TypologyTemplate.events
  'click button.cancel': (e) ->
    e.preventDefault();
    onCancel()
