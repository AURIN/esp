# The template is limited to a single instance, so we can store it and reference it in helper
# methods.
templateInstance = null
TemplateClass = Template.design;

collectionToForm =
  'entities': 'entityForm'
  'typologies': 'typologyForm'

TemplateClass.created = ->
  templateInstance = @

TemplateClass.rendered = ->
  # TODO(aramk) Data is what is passed to the template, not the data on the instance.
  @data ?= {}

  # TODO(aramk) Make Renderer a Meteor module.
  atlasNode = @find('.atlas')

  populateTable = ->

    addRow = (data, args) ->
      id = data.id
      args = Setter.merge({
        table: $table
        showCallback: renderer.showEntity.bind(renderer)
        hideCallback: renderer.hideEntity.bind(renderer)
      }, args)
      $visibilityCheckbox = $('<div class="ui checkbox"><input type="checkbox"><label></label></div>')
      .checkbox({
          onEnable: =>
            args.showCallback.call(this, id)
          onDisable: =>
            args.hideCallback.call(this, id)
        })
      $row = $('<tr><td></td><td>' + (data.name || id) +
        '</td><td class="extra buttons"></td></tr>')
      $('td:first', $row).append($visibilityCheckbox)
      $(args.table).append($row)
      $row

    _.each(renderer.assets, (asset, id) ->
      $row = addRow(asset, {
        showCallback: renderer.showAsset.bind(renderer)
        hideCallback: renderer.hideAsset.bind(renderer)})
      $row.addClass('heading')
      $zoomButton = $('<div class="ui button icon zoom">' +
        '<i class="zoom in icon"></i></div>').click -> renderer.zoomAsset(id)
      $('.extra.buttons', $row).append($zoomButton)
      _.each(asset.entities, (entity, i) ->
        entity.name = entity.name || ('Entity ' + (i + 1))
        addRow(entity)
      )
    )

  $table = $(@find('.ui.table'))
  # Don't show Atlas viewer.
  if Window.getVarBool('atlas') == false
    # Create a blank renderer
    renderer =
      assets: []
      showEntity: -> null
      hideEntity: -> null
    populateTable
  else
    require([
        'atlas-cesium/core/CesiumAtlas'
      ], (CesiumAtlas) =>
      console.debug('Creating atlas-cesium')
      cesiumAtlas = new CesiumAtlas()

      console.debug('Attaching atlas-cesium')
      cesiumAtlas.attachTo(atlasNode)

      cesiumAtlas.publish('debugMode', true)

      renderer = new AtlasRenderer()
      renderer.startup({
        atlas: cesiumAtlas,
        assets: Features.find({}).fetch()
      })
      @data.renderer = renderer
      populateTable
    )

TemplateClass.helpers
  entities: -> Entities.find()
  typologies: -> Typologies.find()
  tableSettings: ->
    fields: [
      key: 'name'
      label: 'Name'
    ]
    rowsPerPage: 100000
    showNavigation: 'never'
    onCreate: (data) ->
      collectionName = Collections.getName(data.collection)
      formName = collectionToForm[collectionName]
      console.debug 'onCreate', arguments, collectionName, formName
      TemplateClass.setUpFormPanel templateInstance, Template[formName]
    onEdit: (data, doc) ->
      collectionName = Collections.getName(data.collection)
      formName = collectionToForm[collectionName]
      console.debug 'onEdit', arguments, collectionName, formName
      TemplateClass.setUpFormPanel templateInstance, Template[formName], doc

getSidebar = (template) ->
  $(template.find('.main.container > .content > .sidebar'))

TemplateClass.addPanel = (template, component) ->
  console.debug 'addPanel', template, component
  $container = getSidebar(template)
  $panel = $('<div class="panel"></div>')
  $('>.panel', $container).hide();
  $container.append $panel
  UI.insert component, $panel[0]

TemplateClass.removePanel = (template, component) ->
  console.debug 'Removing panel', this, template, component
  $(component.dom.getNodes()).parent().remove()
  component.dom.remove()
  $container = getSidebar(template)
  $('>.panel:last', $container).show()

TemplateClass.setUpPanel = (template, panelTemplate, data) ->
  panel = UI.renderWithData panelTemplate, data
  TemplateClass.addPanel template, panel
  panel

TemplateClass.setUpFormPanel = (template, formTemplate, doc, settings) ->
  settings ?= {}
  data =
    doc: doc, settings: settings
  panel = TemplateClass.setUpPanel template, formTemplate, data
  callback = -> TemplateClass.removePanel template, panel
  settings.onCancel = settings.onSuccess = callback
  panel

#TemplateClass.events
#  'click .entities .add.item': (e, template) ->
#    TemplateClass.setUpFormPanel template, Template.entityForm
#  'dblclick .entities .edit': (e, template) ->
#    # TODO(aramk)
#    null
#  'dblclick .typologies .edit': (e, template) ->
#    TemplateClass.setUpFormPanel template, Template.typologyForm, @
