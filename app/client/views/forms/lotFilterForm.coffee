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
    fpaMin:
      label: 'Min. Lot Area'
      type: Number
      decimal: true
      optional: true
    fpaMax:
      label: 'Max. Lot Area'
      type: Number
      decimal: true
      optional: true
    heightMin:
      label: 'Min. Height'
      type: Number
      decimal: true
      optional: true
    heightMax:
      label: 'Max. Height'
      type: Number
      decimal: true
      optional: true
    limit:
      label: 'Limit'
      type: Number
      optional: true

  formName = 'lotFilterForm'
  collection = Lots

  Form = Forms.defineModelForm
    name: formName
    schema: schema

    onRender: ->
      setFloorCeil = (results, $min, $max) ->
        values = Object.keys(results)
        min = Math.floor(Math.min.apply(null, values))
        max = Math.ceil(Math.max.apply(null, values))
        if values.length > 0
          $min.val(min)
          $max.val(max)

      $fpaMin = getFpaMinInput(@)
      $fpaMax = getFpaMaxInput(@)
      LotUtils.getAreas({indexByArea: true}).then (fpaResults) ->
        setFloorCeil(fpaResults, $fpaMin, $fpaMax)

      $heightMin = getHeightMinInput(@)
      $heightMax = getHeightMaxInput(@)
      heightResults = SchemaUtils.getParameterValues(Lots.findByProject(), 'space.height',
          {indexByValues: true})
      setFloorCeil(heightResults, $heightMin, $heightMax)

      # Submit the form to perform the initial selection.
      _.delay (=> @$('form').first().submit()), 300
    
    onSubmit: (doc) ->
      typologyClass = doc.class
      develop = doc.develop
      allocated = doc.allocated
      fpaMin = doc.fpaMin
      fpaMax = doc.fpaMax
      heightMin = doc.heightMin
      heighMax = doc.heightMax
      limit = doc.limit
      lotIds = []
      LotUtils.getAreas().then (results) ->
        # Shuffle to prevent selecting consecutive lots every time.
        shuffledResults = {}
        _.each _.shuffle(_.keys(results)), (lotId) -> shuffledResults[lotId] = results[lotId]
        _.some shuffledResults, (area, lotId) ->
          return true if limit? && lotIds.length >= limit
          lot = Lots.findOne(lotId)
          height = SchemaUtils.getParameterValue(lot, 'space.height')
          if SchemaUtils.getParameterValue(lot, 'general.class') != typologyClass ||
              (fpaMin? && area < fpaMin) || (fpaMax? && area > fpaMax) ||
              (height? && heightMin? && height < heightMin) ||
              (height? && heightMax? && height > heightMax) ||
              SchemaUtils.getParameterValue(lot, 'general.develop') != develop ||
              lot.entity? != allocated
            return false
          lotIds.push(lotId)
          return false
        AtlasManager.deselectAllEntities()
        AtlasManager.selectEntities(lotIds)
      false

  Form.helpers

    classes: -> Collections.createTemporary(Typologies.getAllocatableClassItems())
    defaultClass: -> 'RESIDENTIAL'

  getFpaMinInput = (template) -> getField('fpaMin', template)
  getFpaMaxInput = (template) -> getField('fpaMax', template)
  getHeightMinInput = (template) -> getField('heightMin', template)
  getHeightMaxInput = (template) -> getField('heightMax', template)
  
  getField = (name, template) -> getTemplate(template).$('[name="' + name + '"]')
  getTemplate = (template) -> Templates.getNamedInstance(formName, template)
