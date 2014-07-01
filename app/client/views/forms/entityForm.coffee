formName = 'entityForm'
collection = null
collectionName = null
EntityTemplate = Template[formName]

# TODO(aramk) Provide callback in settings
onSuccess = ->
  Session.set('currentPanel', 'default')
onCancel = ->
  Session.set('currentPanel', 'default')

EntityTemplate.created = ->
  @data ?= {}
  collection = Entities
  collectionName = collection._name

EntityTemplate.rendered = ->
  AutoForm.resetForm(formName)
  @data ?= {}

AutoForm.addHooks formName,
  onSubmit: (insertDoc, updateDoc, currentDoc) ->
    $typology = $(@template.find('[name="typology"]'))
    insertDoc.typology = $typology.val()
    updateDoc.$set = insertDoc
  onSuccess: (operation, result) ->
    AutoForm.resetForm(formName)
    onSuccess()

EntityTemplate.helpers
  collection: -> collection
  formName: -> formName
  formType: -> if @doc then 'update' else 'insert'
  submitText: -> if @doc then 'Save' else 'Create'
  typology: -> if @doc then @doc.typology else null

EntityTemplate.events
  'click button.cancel': (e) ->
    e.preventDefault();
    onCancel()
