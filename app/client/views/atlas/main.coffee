Template.main.rendered = ->
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

Template.main.helpers
  entities: -> Entities.find()
  typologies: -> Typologies.find()

Template.main.addPanel = (template, component) ->
  console.log 'addPanel', template, component
  $container = $(template.find('.sidebar'))
  $panel = $('<div class="panel"></div>')
  $container.append $panel
  UI.insert component, $panel[0]

Template.main.removePanel = (template, component) ->
  console.log 'Removing panel', this, template, component
  $(component.dom.getNodes()).parent().remove()
  component.dom.remove()

Template.main.setUpPanel = (template, panelTemplate, data) ->
  panel = UI.renderWithData panelTemplate, data
  Template.main.addPanel template, panel
  panel

Template.main.setUpFormPanel = (template, formTemplate, doc, settings) ->
  settings ?= {}
  data = doc: doc, settings: settings
  panel = Template.main.setUpPanel template, formTemplate, data
  callback = -> Template.main.removePanel template, panel
  settings.onCancel = settings.onSuccess = callback
  panel

Template.main.events
  'click .entities .edit': (e, template) ->
    Template.main.setUpFormPanel template, Template.entityForm, @
  'click .typologies .edit': (e, template) ->
    Template.main.setUpFormPanel template, Template.typologyForm, @
