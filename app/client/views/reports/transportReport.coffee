Meteor.startup ->
  Reports.define
    name: 'transportReport'
    title: 'Transport Report'
    typologyClass: 'RESIDENTIAL'

    fields: [
      # Average aggregation is used for parameters which only use project parameters, since the
      # value is the same for all entities.

      {title: 'Vehicle Kilometres Travelled'}
      {param: 'transport.vkt_household_day', aggregate: 'average'}
      {param: 'transport.vkt_person_day', aggregate: 'average'}
      {param: 'transport.vkt_household_day', label: 'VKT Estimate (total Precinct)'}
      
      {param: 'transport.vkt_household_year', aggregate: 'average'}
      {param: 'transport.vkt_person_year', aggregate: 'average'}
      {param: 'transport.vkt_household_year', label: 'VKT Estimate (total Precinct)'}

      {param: 'transport.ghg_household_day', aggregate: 'average'}
      {param: 'transport.ghg_person_day', aggregate: 'average'}
      {param: 'transport.ghg_household_day', label: 'GHG Estimate (total Precinct)'}

      {param: 'transport.ghg_household_year', aggregate: 'average'}
      {param: 'transport.ghg_person_year', aggregate: 'average'}
      {param: 'transport.ghg_household_year', label: 'GHG Estimate (total Precinct)'}
    ]
