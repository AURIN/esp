Template.helpButton.rendered = ->
  setHelpMode = (mode) -> Session.set 'helpMode', mode
  getHelpMode = -> Session.get 'helpMode'

  $button = $(@find('.button')).state()
  $button.click ->
    isActive = $button.hasClass('active')
    setHelpMode(isActive)

  Deps.autorun ->
    # Must use Session directly to ensure reactivity
    isActive = Session.get('helpMode') ? false
    $button.toggleClass('active', isActive)
    $button.text(if isActive then 'Help On' else 'Help Off')

  unless getHelpMode?
    setHelpMode true
