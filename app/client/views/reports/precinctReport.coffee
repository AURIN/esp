Meteor.startup ->
  Reports.define
    name: 'precinctReport'
    title: 'Precinct Report'

    fields: [
      {title: 'Space'}
      {param: 'space.lotsize'}

      {title: 'Embodied Carbon'}
      {param: 'embodied_carbon.e_co2_green'}
      {param: 'embodied_carbon.e_co2_imp'}
      {param: 'embodied_carbon.e_co2_emb'}
      {param: 'embodied_carbon.i_co2_emb'}
      {param: 'embodied_carbon.t_co2_emb'}

      {title: 'Operating Carbon'}
      {param: 'operating_carbon.co2_heat'}
      {param: 'operating_carbon.co2_cool'}
      {param: 'operating_carbon.co2_light'}
      {param: 'operating_carbon.co2_hwat'}
      {param: 'operating_carbon.co2_cook'}
      {param: 'operating_carbon.co2_app'}
      {param: 'operating_carbon.co2_op_tot'}
      {param: 'operating_carbon.co2_trans'}

      {title: 'Water Demand'}
      {param: 'water_demand.i_wu_pot'}
      {param: 'water_demand.i_wu_bore'}
      {param: 'water_demand.i_wu_rain'}
      {param: 'water_demand.i_wu_treat'}
      {param: 'water_demand.i_wu_grey'}
      {param: 'water_demand.i_wu_total'}
      {param: 'water_demand.e_wd_lawn'}
      {param: 'water_demand.e_wd_ap'}
      {param: 'water_demand.e_wd_hp'}
      {param: 'water_demand.e_wd_total'}
      {param: 'water_demand.wu_pot_tot'}
      {param: 'water_demand.wd_total'}

      {title: 'Stormwater'}
      {param: 'stormwater.runoff'}

      {title: 'Parking'}
      {param: 'parking.parking_ga'}
      {param: 'parking.parking_sl'}
      {param: 'parking.parking_ug'}
      {param: 'parking.parking_t'}

    ]
