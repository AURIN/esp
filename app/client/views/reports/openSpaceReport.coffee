Meteor.startup ->
  Reports.define
    name: 'openSpaceReport'
    title: 'Open Space Report'
    fields: [
      {title: 'General'}
      {param: 'general.occupants'}
      {param: 'general.jobs'}

      {title: 'Space'}
      {param: 'space.lotsize'}
      {param: 'space.extland'}
      {param: 'space.fpa'}
      {param: 'space.gfa'}
      {param: 'space.ext_land_l'}
      {param: 'space.ext_land_a'}
      {param: 'space.ext_land_h'}
      {param: 'space.ext_land_i'}

      {title: 'Energy'}
      {param: 'energy_demand.en_heat'}
      {param: 'operating_carbon.co2_heat'}

#      {title: 'Financial'}
#      {param: 'financial.local_land_value'}

    ]
