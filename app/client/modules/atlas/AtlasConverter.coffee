# AMD modules.
WKT = Style = Colour = null

class @AtlasConverter

  toGeoEntityArgs: (args) ->
    geoEntity = _.extend({}, args)
    vertices = args.vertices
    height = args.height || 20
    width = args.width || 10
    elevation = args.elevation || 0
    color = args.color
    borderColour = args.borderColor
    # TODO(aramk) Enable opacity in atlas-cesium.
    opacity = args.opacity
    borderOpacity = args.borderOpacity || 1
    geometry = ->
      vertices: vertices,
      elevation: elevation,
      height: height,
      width: width

    # Vertices
    wkt = WKT.getInstance()
    if wkt.isPolygon(vertices)
      geoEntity.polygon = geometry
      geoEntity.displayMode = (height > 0 || elevation > 0) ? 'extrusion': 'footprint'
    else if wkt.isLineString vertices
      geoEntity.line = geometry
    else if vertices != null
      console.warn('Unknown type of vertices', args)

    # Style
    styleArgs = {}
    if color
      Setter.merge(styleArgs, this.toAtlasStyleArgs(color, opacity, 'fill'))
    if borderColour
      Setter.merge(styleArgs, this.toAtlasStyleArgs(borderColour, borderOpacity, 'border'))
    geometry.style = new Style(styleArgs)
    geoEntity

  toAtlasStyleArgs: (colour, opacity, prefix) ->
    styleArgs = {}
    styleArgs[prefix + 'Colour'] = new Colour(colour)
    if opacity != undefined
      styleArgs[prefix + 'Colour'].alpha = opacity
    styleArgs

console.log @AtlasConverter

_.extend(@AtlasConverter, {

  ready: (callback) ->
    require([
        'atlas/util/WKT',
        'atlas/model/Style',
        'atlas/model/Colour'
      ], (_WKT, _Style, _Colour) ->
      WKT = _WKT
      Style = _Style
      Colour = _Colour
      callback()
    )

  newInstance: (callback) ->
    this.ready(->
      callback(new @AtlasConverter())
    )

})
