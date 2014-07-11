Meteor.startup ->
  Reports.define
    name: 'openSpaceReport'
    title: 'Open Space Report'
#    params:
#      general: ['tot_area']
#      environmental: ['pav_area', 'nat_area', 'exo_area', 'lawn_area']
#      economic: ['cost_total']
#      carbon: ['co2_total']
#      water: ['wd_total']
    fields: [
      {title: 'General'}
      {param: 'general.occupants'}
      {title: 'Geometry'}
      {param: 'geometry.lotsize'}
      {param: 'geometry.extland'}
      {param: 'geometry.fpa'}
      {title: 'Energy'}
      {param: 'energy.en_heat'}
      {param: 'energy.co2_heat'}
      # TODO(aramk) Parse issues in CS
#      Reports.defineParamFields({category: 'environmental'
#        params: ['pav_area', 'nat_area', 'exo_area', 'lawn_area']})
#      {param: 'economic.cost_total'}
#      {param: 'carbon.co2_total'}
#      {param: 'water.wd_total'}
    ]
