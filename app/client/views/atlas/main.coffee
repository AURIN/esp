Template.main.created = ->
  Session.set 'currentPanel', 'default'

Template.main.rendered = ->
  @data ?= {}

  # TODO(aramk) Make Renderer a Meteor module.
  atlasNode = @find('.atlas')

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

    $table = $(@find('.ui.table'))

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
        '<i class="zoom in icon"></i></div>').click(->
        renderer.zoomAsset(id))
      $('.extra.buttons', $row).append($zoomButton)
      _.each(asset.entities, (entity, i) ->
        entity.name = entity.name || ('Entity ' + (i + 1))
        addRow(entity)
      )
    )
  )

Template.main.helpers
  isDefaultPanel: ->
    Session.get('currentPanel') == 'default'
  isTypologyPanel: ->
    Session.get('currentPanel') == 'typologies'
  typologies: ->
    Typologies.find()

Template.main.events
  'click .add.item': ->
    Session.set 'currentPanel', 'typologies'
    console.log('Panel changed', Session.get 'currentPanel')