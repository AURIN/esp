$ ->
  # The Atlas resources are stored in the public folders and the style needs to be added manually.
  $css = $('<link rel="stylesheet" type="text/css" href="/design/atlas-cesium/cesium/Source/Widgets/widgets.css" />')
  $('head').append($css)
