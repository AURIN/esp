Meteor.startup ->
  Reports.define
    name: 'residentialReport'
    title: 'Residential Report'
    typologyClass: 'RESIDENTIAL'

    fields: [
      {title: 'Space'}
      {param: 'space.lotsize'}
      {param: 'space.ext_land_l'}
      {param: 'space.ext_land_a'}
      {param: 'space.ext_land_h'}
      {param: 'space.ext_land_i'}
      {param: 'space.extland'}
      {param: 'space.fpa'}
      {param: 'space.gfa_t'}
      {param: 'space.plot_ratio', aggregate: 'average'}
      {param: 'space.dwell_dens', aggregate: 'average'}
      {param: 'space.dwell_tot'}
      {param: 'space.occupants'}

      {title: 'Energy Demand'}
      {param: 'energy_demand.en_heat'}
      {param: 'energy_demand.en_cool'}
      {param: 'energy_demand.en_light'}
      {param: 'energy_demand.en_hwat'}
      {param: 'energy_demand.en_cook'}
      {param: 'energy_demand.en_app'}
      {param: 'energy_demand.en_pv'}
      {param: 'energy_demand.en_total'}

      {title: 'Embodied Carbon'}
      {param: 'embodied_carbon.e_co2_green'}
      {param: 'embodied_carbon.e_co2_imp'}
      {param: 'embodied_carbon.e_co2_emb'}
      {param: 'embodied_carbon.i_co2_emb_intensity_value'}
      {param: 'parking.co2_ug_tot'}
      {param: 'embodied_carbon.t_co2_emb'}

      {title: 'Operating Carbon'}
      {param: 'operating_carbon.co2_heat'}
      {param: 'operating_carbon.co2_cool'}
      {param: 'operating_carbon.co2_light'}
      {param: 'operating_carbon.co2_hwat'}
      {param: 'operating_carbon.co2_cook'}
      {param: 'operating_carbon.co2_app'}
      {param: 'operating_carbon.co2_op_tot'}

      {title: 'Water Demand'}
      {param: 'water_demand.i_wu_pot'}
      {param: 'water_demand.i_wu_rain'}
      {param: 'water_demand.i_wu_total'}
      
      {param: 'water_demand.e_wu_pot'}
      {param: 'water_demand.e_wu_rain'}
      {param: 'water_demand.e_wu_bore'}
      {param: 'water_demand.e_wu_grey'}
      {param: 'water_demand.rain_supply'}

      {param: 'water_demand.e_wd_lawn'}
      {param: 'water_demand.e_wd_ap'}
      {param: 'water_demand.e_wd_hp'}
      {param: 'water_demand.e_wd_total'}
      {param: 'water_demand.wu_pot_tot'}
      {param: 'water_demand.wd_total'}

      {title: 'Stormwater'}
      {param: 'stormwater.runoff'}

      {title: 'Financial'}
      {param: 'financial.cost_land'}
      {param: 'financial.cost_lawn'}
      {param: 'financial.cost_annu'}
      {param: 'financial.cost_hardy'}
      {param: 'financial.cost_imper'}
      {param: 'financial.cost_xland'}
      {param: 'financial.cost_con'}
      {param: 'financial.cost_prop'}
      {param: 'financial.cost_prop', label: 'Average Property Cost', aggregate: 'average'}
      {param: 'financial.cost_op_e'}
      {param: 'financial.cost_op_g'}
      {param: 'financial.cost_op_w'}
      {param: 'financial.cost_op_t'}
      {param: 'financial.cost_op_t', label: 'Average Operating Cost', aggregate: 'average'}

      {title: 'Parking'}
      {param: 'parking.parking_ga'}
      {param: 'parking.parking_sl'}
      {param: 'parking.parking_ug'}
      {param: 'parking.parking_t'}
    ]
