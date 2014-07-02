Meteor.startup ->
  Form = Forms.defineModelForm
    name: 'entityForm'
    collection: 'Entities'
    onSubmit: (insertDoc, updateDoc, currentDoc) ->
      $typology = $(@template.find('[name="typology"]'))
      insertDoc.typology = $typology.val()
      updateDoc.$set = insertDoc

  Form.helpers
    typology: -> @doc?.typology
