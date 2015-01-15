Meteor.startup ->

  schema = new SimpleSchema
    allowNonDevelopment:
      label: 'Allow non-developable'
      desc: 'Whether to allow non-developable Lots to be allocated by changing them to development Lots.'
      type: Boolean
      defaultValue: false
    replace:
      label: 'Replace'
      desc: 'Replace existing allocations if necessary.'
      type: Boolean
      defaultValue: false

  formName = 'autoAllocationForm'
  collection = Lots

  Form = Forms.defineModelForm
    name: formName
    schema: schema

    onSubmit: (doc) ->
      console.log('onSubmit', arguments)
      $table = getTypologyTable()
      typologyIds = Template.collectionTable.getSelectedIds($table)
      lotIds = AtlasManager.getSelectedLots()
      if typologyIds.length == 0
        alert('Please select a Typology.')
      else if lotIds.length == 0
        alert('Please select at least one Lot.')
      else
        LotUtils.autoAllocate({
          lotIds: lotIds
          typologyIds: typologyIds
          allowNonDevelopment: doc.allowNonDevelopment
          replace: doc.replace
        }).then => @done()
      false

  Form.helpers

    typologies: -> Typologies.findByProject()
    tableSettings: ->
      fields: [
        key: 'name'
        label: 'Name'
      ]
      crudMenu: false
      multiSelect: false

  getTypologyTable = (template) -> getTemplate().$('.collection-table')
  getTemplate = (template) -> Templates.getNamedInstance(formName, template)
