@TemplateUtils =

  # TODO(aramk) Is actually the parent element, not the element?
  # TODO(aramk) UI is old and it's now Blaze which has Blaze.Template and Blaze.View.
  getDom: (component) ->
    component._domrange.parentElement
