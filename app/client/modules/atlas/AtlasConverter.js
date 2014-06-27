// AMD modules.
var WKT, Style, Colour;

AtlasConverter = function() {

};
_.extend(AtlasConverter, {

  ready: function(callback) {
    require([
      'atlas/util/WKT',
      'atlas/model/Style',
      'atlas/model/Colour'
    ], function(_WKT, _Style, _Colour) {
      WKT = _WKT;
      Style = _Style;
      Colour = _Colour;
      callback();
    });
  },

  newInstance: function(callback) {
    this.ready(function() {
      callback(new AtlasConverter());
    });
  }

});
_.extend(AtlasConverter.prototype, {

  toGeoEntityArgs: function(args) {
    var geoEntity = _.extend({}, args);
    var vertices = args.vertices,
        height = args.height || 20,
        width = args.width || 10,
        elevation = args.elevation || 0,
        color = args.color,
        borderColour = args.borderColor,
    // TODO(aramk) Enable opacity in atlas-cesium.
        opacity = args.opacity,
        borderOpacity = args.borderOpacity || 1;
    var geometry = {
      vertices: vertices,
      elevation: elevation,
      height: height,
      width: width
    };
    // Vertices
    var wkt = WKT.getInstance();
    if (wkt.isPolygon(vertices)) {
      geoEntity.polygon = geometry;
      geoEntity.displayMode = (height > 0 || elevation > 0) ? 'extrusion' : 'footprint';
    } else if (wkt.isLineString(vertices)) {
      geoEntity.line = geometry;
    } else if (vertices !== null) {
      console.warn('Unknown type of vertices', args);
    }
    // Style
    var styleArgs = {};
    color && Setter.merge(styleArgs, this.toAtlasStyleArgs(color, opacity, 'fill'));
    borderColour &&
    Setter.merge(styleArgs, this.toAtlasStyleArgs(borderColour, borderOpacity, 'border'));
    geometry.style = new Style(styleArgs);
    return geoEntity;
  },

  toAtlasStyleArgs: function(colour, opacity, prefix) {
    var styleArgs = {};
    styleArgs[prefix + 'Colour'] = new Colour(colour);
    if (opacity !== undefined) {
      styleArgs[prefix + 'Colour'].alpha = opacity;
    }
    return styleArgs;
  },

});
