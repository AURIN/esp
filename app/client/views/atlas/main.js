Template.main.rendered = function() {

  // TODO(aramk) Make Renderer a Meteor module.

  this.data = {};
  var atlasNode = this.find('.atlas');

  require([
    'atlas-cesium/core/CesiumAtlas'
  ], function(CesiumAtlas) {

    console.debug('Creating atlas-cesium');
    var cesiumAtlas = new CesiumAtlas();

    console.debug('Attaching atlas-cesium');
    cesiumAtlas.attachTo(atlasNode);

    cesiumAtlas.publish('debugMode', true);

    var renderer = new AtlasRenderer();
    renderer.startup({
      atlas: cesiumAtlas,
      assets: Features.find({}).fetch()
    });
    this.data.renderer = renderer;

    var $table = $(this.find('.ui.table'));

    function addRow(data, args) {
      var id = data.id;
      args = Setter.merge({
        table: $table,
        showCallback: renderer.showEntity.bind(renderer),
        hideCallback: renderer.hideEntity.bind(renderer)
      }, args);
      var $visibilityCheckbox = $('<div class="ui checkbox"><input type="checkbox"><label></label></div>')
          .checkbox({
            onEnable: function() {
              args.showCallback.call(this, id);
            }.bind(this),
            onDisable: function() {
              args.hideCallback.call(this, id);
            }.bind(this)
          });
      var $row = $('<tr><td></td><td>' + (data.name || id) +
          '</td><td class="extra buttons"></td></tr>');
      $('td:first', $row).append($visibilityCheckbox);
      $(args.table).append($row);
      return $row;
    }

    _.each(renderer.assets, function(asset, id) {
      var $row = addRow(asset, {
        showCallback: renderer.showAsset.bind(renderer),
        hideCallback: renderer.hideAsset.bind(renderer)});
      $row.addClass('heading');
      var $zoomButton = $('<div class="ui button icon zoom">' +
          '<i class="zoom in icon"></i></div>').click(function() {
        renderer.zoomAsset(id);
      });
      $('.extra.buttons', $row).append($zoomButton);
      _.each(asset.entities, function(entity, i) {
        entity.name = entity.name || ('Entity ' + (i + 1));
        addRow(entity);
      });
    });

  }.bind(this));

};

Template.main.helpers({

  features: function() {
    return Features.find({});
  }

});
