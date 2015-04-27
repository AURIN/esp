Meteor.startup ->
  Reports.define
    name: 'assetReport'
    title: 'Asset Report'
    typologyClass: 'ASSET'

    fields: [
      {title: 'Embodied Carbon'}
      {param: 'embodied_carbon.t_co2_emb_asset'}

      {title: 'Financial'}
      {param: 'financial.cost_asset'}
    ]
