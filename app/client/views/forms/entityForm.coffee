formName = 'entityForm'
collection = null
collectionName = null
EntityTemplate = Template[formName]

EntityTemplate.created = ->
  collection = Entities
  collectionName = collection._name
  @data ?= {}
  @data.settings ?= {}
  settings = @data.settings
  Forms.preventText(settings)

EntityTemplate.rendered = ->
  @data ?= {}

AutoForm.addHooks formName,
  onSubmit: (insertDoc, updateDoc, currentDoc) ->
    $typology = $(@template.find('[name="typology"]'))
    insertDoc.typology = $typology.val()
    updateDoc.$set = insertDoc
  onSuccess: (operation, result, template) ->
    console.log 'onSuccess', template.data
    AutoForm.resetForm(formName)
    template.data?.settings?.onSuccess?()

EntityTemplate.helpers
  collection: -> collection
  formName: -> formName
  formType: -> if @doc then 'update' else 'insert'
  submitText: -> if @doc then 'Save' else 'Create'
  typology: -> @doc?.typology

EntityTemplate.events
  'click button.cancel': (e, template) ->
    e.preventDefault();
    template.data?.settings?.onCancel?()
