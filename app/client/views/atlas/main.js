Template.main.rendered = function() {

  // TODO(aramk) Make Renderer a Meteor module.

  this.data = {};
  var atlasNode = this.find('.atlas');

  require([
    'atlas-cesium/core/CesiumAtlas',
    'atlas/assets/testWKT'
  ], function(CesiumAtlas, testWKT) {

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
      console.debug('addRow', data, args);
      var id = data.id;
      args = Setter.merge({
        table: $table,
        showCallback: renderer.showEntity,
        hideCallback: renderer.hideEntity
      }, args);
      var $checkbox = $('<div class="ui checkbox"><input type="checkbox"><label></label></div>')
          .checkbox({
            onEnable: function() {
              args.showCallback.call(this, id);
            }.bind(this),
            onDisable: function() {
              args.hideCallback.call(this, id);
            }.bind(this)
          });
      var $row = $('<tr><td></td><td>' + (data.name || id) + '</td></tr>');
      $('td:first', $row).append($checkbox);
      $(args.table).append($row);
      return $row;
    }

    _.each(renderer.assets, function(asset, id) {
      var $row = addRow(asset, {showCallback: this.showAsset, hideCallback: this.hideAsset});
      $row.addClass('heading');
      _.each(asset.entities, function(entity) {
        addRow(entity);
      });
    });

//    var features = Features.find({}).fetch();
//    _.each(features, function (feature) {
//      renderer.addAsset(feature);
//    });

    // Show sample WKT input.
//    var i = 0;
//    var args = {};
//    args.show = true;
//    args.displayMode = 'extrusion';
//    testWKT.forEach(function(wkt) {
//      args.id = i++;
//      args.polygon = {
//        vertices: wkt,
//        elevation: 0,
//        height: 50
//      };
//      cesiumAtlas.publish('entity/show', args);
//    });
//    cesiumAtlas._managers.event.handleExternalEvent('camera/zoomTo', {
//      position: {
//        latitude: -37.8,
//        longitude: 144.96,
//        elevation: 2000
//      }
//    });

  }.bind(this));

};

Template.main.helpers({

  features: function() {
    return Features.find({});
  }

});

Template.main.events({

  'click .ui.checkbox': function(event, template) {
    var feature = this;
//    require(['lib/Renderer'], function(Renderer) {
    feature.id = feature.name;
    _.each(feature.entities, function(entity, i) {
      entity.id = feature.id + '-' + i;
      entity._asset = feature;
//        Renderer.addEntity(entity);
    });
//      Renderer._showAsset(feature);
//    });
  }

});
