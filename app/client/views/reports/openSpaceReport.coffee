Meteor.startup ->
  Reports.define
    name: 'openSpaceReport'
    title: 'Open Space Report'
    typologyClass: 'OPEN_SPACE'

    fields: [
      {title: 'Space'}
      {param: 'space.ext_land_l', label: 'Lawn Area'}
      {param: 'space.ext_land_a', label: 'Annuals Area'}
      {param: 'space.ext_land_h', label: 'Hardy Area'}
      {param: 'space.ext_land_i', label: 'Impermeable Area'}
      {param: 'space.lotsize', label: 'Total Area'}

      {title: 'Embodied Carbon'}
      {param: 'embodied_carbon.e_co2_green'}
      {param: 'embodied_carbon.e_co2_imp'}
      {param: 'embodied_carbon.t_co2_emb'}

      {title: 'Water Demand'}
      {param: 'water_demand.e_wd_lawn', label: 'Lawn Water Demand'}
      {param: 'water_demand.e_wd_ap', label: 'Annuals Water Demand'}
      {param: 'water_demand.e_wd_hp', label: 'Hardy Water Demand'}
      {param: 'water_demand.e_wd_total', label: 'Total Water Demand'}
      {param: 'water_demand.e_wu_rain'}
      {param: 'water_demand.e_wu_bore'}
      {param: 'water_demand.e_wu_grey'}

      {title: 'Stormwater'}
      {param: 'stormwater.runoff'}

      {title: 'Financial'}
      {param: 'financial.cost_land'}
      {param: 'financial.cost_lawn'}
      {param: 'financial.cost_annu'}
      {param: 'financial.cost_hardy'}
      {param: 'financial.cost_imper'}
      {param: 'financial.cost_xland'}
      {param: 'financial.cost_prop'}
      {param: 'financial.cost_prop', label: 'Average Property Cost', aggregate: 'average'}
      {param: 'financial.cost_op_w'}
    ]
