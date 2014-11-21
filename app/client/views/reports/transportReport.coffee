Meteor.startup ->
  Reports.define
    name: 'transportReport'
    title: 'Transport Report'
    typologyClass: 'RESIDENTIAL'

    fields: [
      {title: 'Vehicle Kilometres Travelled'}
      {param: 'transport.vkt_household_day'}
      
    ]
