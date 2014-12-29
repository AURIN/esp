Meteor.startup ->
  Reports.define
    name: 'mixedUseReport'
    title: 'Mixed Use Report'
    typologyClass: 'MIXED_USE'

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
      {param: 'space.plot_ratio'}
      {param: 'space.jobs'}

      {title: 'Energy Demand'}
      {param: 'energy_demand.en_use_e'}
      {param: 'energy_demand.en_use_g'}
      {param: 'energy_demand.en_pv'}
      {param: 'energy_demand.en_total'}

      {title: 'Embodied Carbon'}
      {param: 'embodied_carbon.e_co2_green'}
      {param: 'embodied_carbon.e_co2_imp'}
      {param: 'embodied_carbon.e_co2_emb'}
      {param: 'embodied_carbon.i_co2_emb_intensity_value'}
      {param: 'embodied_carbon.t_co2_emb'}

      {title: 'Operating Carbon'}
      {param: 'operating_carbon.co2_op_e'}
      {param: 'operating_carbon.co2_op_g'}
      {param: 'operating_carbon.co2_op_tot'}

      {title: 'Water Demand'}
      {param: 'water_demand.i_wu_total'}

      {param: 'water_demand.e_wu_pot'}
      {param: 'water_demand.e_wu_bore'}
      {param: 'water_demand.e_wu_storm'}
      {param: 'water_demand.e_wu_treat'}
      {param: 'water_demand.e_wu_grey'}

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
      {param: 'parking.parking_sl'}
      {param: 'parking.parking_ug'}
      {param: 'parking.parking_t'}
    ]
