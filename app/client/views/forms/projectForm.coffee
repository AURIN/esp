Meteor.startup ->

  close = ->
    unless Router.current().route.name == 'design'
      Router.goToLastPath() or Router.go('projects')

  Form = Forms.defineModelForm
    name: 'projectForm'
    collection: 'Projects'
    onSuccess: close
    onCancel: close

  Form.helpers
    project: -> Projects.getCurrentId()

  Form.events
    'click .button.view-current': (e, template) ->
      AtlasManager.getCurrentCamera
        callback: (camera) ->
          stats = camera.getStats()
          setLocationField = (name, value) ->
            $(Forms.findFieldInput(template, name)).val(value)
          setLocationField 'parameters.location.lat', stats.position.latitude
          setLocationField 'parameters.location.lng', stats.position.longitude
          setLocationField 'parameters.location.cam_elev', stats.position.elevation
    'click .button.view-apply': (e, template) ->
      AtlasManager.getCurrentCamera
        callback: (camera) ->
          getFieldValue = (name) ->
            value = $(Forms.findFieldInput(template, name)).val()
            if value.trim() != '' then parseFloat(value) else null
          position =
            latitude: getFieldValue 'parameters.location.lat'
            longitude: getFieldValue 'parameters.location.lng'
            elevation: getFieldValue 'parameters.location.cam_elev'
          if position.latitude? && position.longitude? && position.elevation?
            camera.setPosition(position)
          else
            console.error('Cannot change camera position - must provide longitude, latitude and elevation',
              position)

