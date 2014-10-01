TemplateClass = Template.loader

TemplateClass.helpers
  text: -> @?.text ? 'Loading'

TemplateClass.setActive = (domNode, active) ->
  $dimmer = $(domNode).closest('.dimmer')
  $dimmer.toggleClass('active', active)
