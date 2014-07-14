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