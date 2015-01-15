Meteor.startup ->

  schema = new SimpleSchema

  formName = 'autoAllocationForm'
  collection = Lots

  Form = Forms.defineModelForm
    name: formName
    schema: schema

    onSubmit: (doc) ->
      console.log('onSubmit', arguments)
      $table = getTypologyTable()
      typologyIds = Template.getSelectedIds($table)[0]
      lots = AtlasManager.getSelectedLots()
      lotIds = _.map lots, (lot) -> lot._id
      LotUtils.autoAllocate
        lotIds: lotIds
        typologyIds: typologyIds
        nonDevelopment: true
        replace: true
      false

  Form.helpers

    typologies: -> Typologies.findByProject()
    tableSettings: ->
      fields: [
        key: 'name'
        label: 'Name'
      ]
      multiSelect: false

  getTypologyTable = (template) -> getTemplate().$('.collection-table')
  getTemplate = (template) -> Templates.getNamedInstance(formName, template)
