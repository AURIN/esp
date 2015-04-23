Meteor.startup ->
  Reports.define
    name: 'precinctReport'
    title: 'Precinct Report'

    fields: [
      {title: 'Planning'}
      {param: 'space.lotsize', label: 'Total Lot Area'}
      {param: 'space.fpa', label: 'Total Footprint Area'}
      {param: 'space.gfa', label: 'Total Gross Floor Area'}
      {param: 'space.plot_ratio', label: 'Total Plot Ratio', aggregate: 'average'}
      {param: 'space.occupants', label: 'Total Residents'}
      {param: 'space.jobs', label: 'Total Jobs'}
      {template: 'landUseChart'}

      {title: 'Energy Demand'}
      {param: 'energy_demand.en_total', label: 'Total Operating'}

      {title: 'Embodied Carbon'}
      {param: 'embodied_carbon.t_co2_emb', label: 'Total Embodied'}

      {title: 'Operating Carbon'}
      {param: 'operating_carbon.co2_op_tot', label: 'Total Operating'}

      {title: 'Water Demand'}
      {param: 'water_demand.wu_pot_tot', label: 'Total Potable Operating'}
      {param: 'water_demand.wd_total', label: 'Total Operating'}

      {title: 'Stormwater'}
      {param: 'stormwater.runoff', label: 'Stormwater Runoff'}

      {title: 'Financial'}
      {param: 'financial.cost_land', label: 'Total Cost - Land'}
      {param: 'financial.cost_xland', label: 'Total Cost - Landscaping'}
      {param: 'financial.cost_con', label: 'Total Cost - Construction'}
      {param: 'financial.cost_prop', label: 'Total Cost - Property'}
      {param: 'financial.cost_op_e', label: 'Total Cost - Electricity Usage'}
      {param: 'financial.cost_op_g', label: 'Total Cost - Gas Usage'}
      {param: 'financial.cost_op_w', label: 'Total Cost - Water Usage'}
      {param: 'financial.cost_op_t', label: 'Total Cost - All Operating'}
      
      {title: 'Parking'}
      {param: 'parking.parking_sl', label: 'Total Parking - Street Level'}
      {param: 'parking.parking_ga', label: 'Total Parking - Garage'}
      {param: 'parking.parking_ug', label: 'Total Parking - Underground'}
      {param: 'parking.parking_t', label: 'Total Parking - All Parking'}
    ]
