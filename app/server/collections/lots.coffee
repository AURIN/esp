Meteor.methods

  'lots/from/c3ml': (c3mls) ->
    lotIds = []
    for c3ml in c3mls
      polygon = c3ml.polygon
      unless polygon?
        continue
      wktString = ''
      id = Lots.insert({
        parameters:
          general:
            geom: wktString
      })
      lotIds.push(id)
    lotIds
