Meteor.startup ->
  Reports.define
    name: 'cogenReport'
    title: 'Cogen/Trigen Report'

    fields: [
      {title: 'Demand for Cogen/Trigen Energy'}
      {param: 'cogen.demand.elec'}
      {param: 'cogen.demand.heat'}
      {param: 'cogen.demand.cool'}
      {param: 'cogen.demand.hwat'}
      {param: 'cogen.demand.therm'}
      {param: 'cogen.demand.total'}

      {title: 'Supply of Cogen/Trigen Energy'}
      {param: 'energy.cogen.spec.plant_size', aggregate: 'average'}
      {param: 'energy.cogen.spec.plant_eff', aggregate: 'average'}
      {param: 'energy.cogen.spec.cop_heat', aggregate: 'average'}
      {param: 'energy.cogen.spec.cop_cool', aggregate: 'average'}

      {param: 'energy.cogen.operation.op_hrs_day', aggregate: 'average'}
      {param: 'energy.cogen.operation.op_days_wk', aggregate: 'average'}
      {param: 'energy.cogen.operation.op_days_wk', aggregate: 'average'}
      {param: 'energy.cogen.operation.op_wks_year', aggregate: 'average'}

      {param: 'energy.cogen.output.elec_output', aggregate: 'average'}
      {param: 'energy.cogen.output.th_en_heat', aggregate: 'average'}
      {param: 'energy.cogen.output.th_en_cool', aggregate: 'average'}

      {param: 'energy.cogen.thermal.prpn_heat_cap', aggregate: 'average'}
      {param: 'energy.cogen.thermal.prpn_th_en_h', aggregate: 'average'}

      {param: 'cogen.balance.excess_elec'}
      {param: 'cogen.balance.excess_heat'}
      {param: 'cogen.balance.excess_cool'}
      
      {param: 'energy.cogen.operating_carbon.co2_op_total', aggregate: 'average'}
      {param: 'energy.cogen.operating_carbon.co2_op_e_cogen', aggregate: 'average'}
      {param: 'energy.cogen.operating_carbon.co2_op_h_cogen', aggregate: 'average'}
      {param: 'energy.cogen.operating_carbon.co2_op_c_cogen', aggregate: 'average'}
      {param: 'energy.cogen.operating_carbon.co2_int_elec', aggregate: 'average'}
      {param: 'energy.cogen.operating_carbon.co2_int_heat', aggregate: 'average'}
      {param: 'energy.cogen.operating_carbon.co2_int_cool', aggregate: 'average'}
    ]
