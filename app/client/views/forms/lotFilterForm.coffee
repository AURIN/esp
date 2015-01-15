Meteor.startup ->

  schema = new SimpleSchema
    class:
      type: String
      optional: true
    develop:
      label: 'For Development'
      type: Boolean
      defaultValue: true
    allocated:
      label: 'Allocated'
      type: Boolean
      defaultValue: false
    fpa_gte:
      label: 'FPA Greater Than or Equal'
      type: Number
      decimal: true
      optional: true
    fpa_lte:
      label: 'FPA Less Than or Equal'
      type: Number
      decimal: true
      optional: true
    count:
      label: 'Count'
      type: Number
      optional: true

  formName = 'lotFilterForm'
  collection = Lots

  Form = Forms.defineModelForm
    name: formName
    schema: schema

    onRender: ->
      $lte = getFpaLteInput(@)
      $gte = getFpaGteInput(@)
      LotUtils.getAreas({indexByArea: true}).then (fpas) ->
        values = Object.keys(fpas)
        min = Math.floor(Math.min.apply(null, values))
        max = Math.ceil(Math.max.apply(null, values))
        if values.length > 0
          $gte.val(min)
          $lte.val(max)
    
    onSubmit: (doc) ->
      typologyClass = doc.class
      fpaGte = doc.fpa_gte
      fpaLte = doc.fpa_lte
      develop = doc.develop
      allocated = doc.allocated
      count = doc.count
      lotIds = []
      LotUtils.getAreas().then (results) =>
        _.some _.values(results), (result, i) ->
          return true if count? && i >= count
          lot = result.model
          area = result.area
          if SchemaUtils.getParameterValue(lot, 'general.class') != typologyClass ||
              (fpaGte? && area < fpaGte) || (fpaLte? && area > fpaLte) ||
              SchemaUtils.getParameterValue(lot, 'general.develop') != develop ||
              lot.entity? != allocated
            return false
          lotIds.push(lot._id)
          return false
        AtlasManager.deselectAllEntities()
        AtlasManager.selectEntities(lotIds)
      false

  Form.helpers

    classes: -> Collections.createTemporary(Typologies.getAllocatableClassItems())
    defaultClass: -> 'RESIDENTIAL'

  getFpaLteInput = (template) -> getTemplate(template).$('[name="fpa_lte"]')
  getFpaGteInput = (template) -> getTemplate(template).$('[name="fpa_gte"]')
  getTemplate = (template) -> Templates.getNamedInstance(formName, template)
