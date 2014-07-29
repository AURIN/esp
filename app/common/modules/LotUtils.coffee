@LotUtils =

  fromC3ml: (c3mls, callback) ->
    lotIds = []
    doneCalls = 0
    polygonC3mls = []
    done = (id) ->
      lotIds.push(id)
      doneCalls++
      console.debug('done', id, doneCalls, c3mls.length)
      if doneCalls == polygonC3mls.length
        callback(lotIds)
    _.each c3mls, (c3ml) ->
      if c3ml.type == 'polygon'
        polygonC3mls.push(c3ml)
    _.each polygonC3mls, (c3ml, i) ->
      coords = c3ml.coordinates
      # TODO(aramk) Use the names from meta-data
      name = 'Lot #' + (i + 1)
      # C3ml coordinates are in (longitude, latitude), but WKT is the reverse.
      WKT.swapCoords coords, (coords) ->
        WKT.fromVertices coords, (wkt) ->
          lot = {
            name: name
            project: Projects.getCurrentId()
            parameters:
            # TODO(aramk) pass extra args for this.
    #            general:
    #              class: null
              space:
                geom: wkt
                height: c3ml.height
          }
          id = Lots.insert(lot)
          console.debug('lot', id, lot)
          done(id)
