Meteor.startup ->
  Reports.define
    name: 'pathwayReport'
    title: 'Pathway Report'
    typologyClass: 'PATHWAY'

    fields: [
      {title: 'Space'}
      {param: 'space.length'}
      {param: 'space.area'}

      {title: 'Parking'}
      {param: 'parking.parking_rd_total'}

      {title: 'Composition'}
      {param: 'composition.rd_area'}
      {param: 'composition.prk_area'}
      {param: 'composition.fp_area'}
      {param: 'composition.bp_area'}
      {param: 'composition.ve_area'}
      # {param: 'composition.area_tot'}

      {title: 'Stormwater'}
      {param: 'stormwater.runoff_rd'}

      {title: 'Embodied Carbon'}
      {param: 'embodied_carbon.pathways.co2_rd'}
      {param: 'embodied_carbon.pathways.co2_prk'}
      {param: 'embodied_carbon.pathways.co2_fp'}
      {param: 'embodied_carbon.pathways.co2_bp'}
      {param: 'embodied_carbon.pathways.co2_ve'}
      {param: 'embodied_carbon.pathways.co2_embod'}

      {title: 'Financial'}
      {param: 'financial.pathways.cost_land'}
      {param: 'financial.pathways.cost_rd'}
      {param: 'financial.pathways.cost_prk'}
      {param: 'financial.pathways.cost_fp'}
      {param: 'financial.pathways.cost_bp'}
      {param: 'financial.pathways.cost_ve'}
      {param: 'financial.pathways.cost_con'}
      {param: 'financial.pathways.cost_total'}
    ]
