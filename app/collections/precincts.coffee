PrecinctSchema = new SimpleSchema
  name:
    label: 'Name'
    type: String,
    index: true,
    unique: true
  desc:
    label: 'Description'
    type: String
    optional: true
  location:
    label: 'Location'
    type: String
    desc: 'A location name or latitude, longitude coordinate.'

@Precincts = new Meteor.Collection 'precinct', schema: PrecinctSchema
Precincts.allow(Collections.allowAll())

Precincts.setCurrentId = (id) -> Session.set('precinctId', id)
#  console.log('finding precinct')
#  precinct = Precincts.findOne(id)
#  unless precinct
#    throw new Error('Cannot find precinct', id)
#  Session.set('precinct', precinct)
#  precinct
Precincts.getCurrent = ->
  id = Precincts.getCurrentId()
  Precincts.findOne(id)
#  Session.get('precinct')
Precincts.getCurrentId = -> Session.get('precinctId')
