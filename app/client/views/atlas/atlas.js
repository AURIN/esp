Template.atlas.rendered = function() {

  var atlasNode = this.find('.atlas');

  require([
    'atlas-cesium/core/CesiumAtlas',
    'atlas/assets/testWKT'
  ], function (CesiumAtlas, testWKT) {

    console.debug('Creating atlas-cesium');
    var cesiumAtlas = new CesiumAtlas();

    console.debug('Attaching atlas-cesium');
    cesiumAtlas.attachTo(atlasNode);

    cesiumAtlas.publish('debugMode', true);

    var i = 0;
    var args = {};
    args.show = true;
    args.displayMode = 'extrusion';
    testWKT.forEach(function(wkt) {
      args.id = i++;
      args.polygon = {
        vertices: wkt,
        elevation: 0,
        height: 50
      };
      cesiumAtlas.publish('entity/show', args);
    });
    cesiumAtlas._managers.event.handleExternalEvent('camera/zoomTo', {
      position: {
        latitude: -37.8,
        longitude: 144.96,
        elevation: 2000
      }
    });

  });

};
