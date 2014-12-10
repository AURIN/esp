Meteor.startup ->
  Reports.define
    name: 'transportReport'
    title: 'Transport Report'
    typologyClass: 'RESIDENTIAL'

    fields: [
      # Average aggregation is used for parameters which only use project parameters, since the
      # value is the same for all entities.

      {title: 'Vehicle Kilometres Travelled'}

      {param: 'transport.vkt_household_day', aggregate: 'average'}
      {param: 'transport.vkt_person_day', aggregate: 'average'}
      {param: 'transport.vkt_household_day', label: 'VKT Estimate (total Precinct)'}
      
      {param: 'transport.vkt_household_year', aggregate: 'average'}
      {param: 'transport.vkt_person_year', aggregate: 'average'}
      {param: 'transport.vkt_household_year', label: 'VKT Estimate (total Precinct)'}

      {param: 'transport.ghg_household_day', aggregate: 'average'}
      {param: 'transport.ghg_person_day', aggregate: 'average'}
      {param: 'transport.ghg_household_day', label: 'GHG Estimate (total Precinct)'}

      {param: 'transport.ghg_household_year', aggregate: 'average'}
      {param: 'transport.ghg_person_year', aggregate: 'average'}
      {param: 'transport.ghg_household_year', label: 'GHG Estimate (total Precinct)'}

      {title: 'Mode Share'}

      {param: 'transport.mode_share_car_driver'}
      {param: 'transport.mode_share_car_passenger'}
      {param: 'transport.mode_share_transit'}
      {param: 'transport.mode_share_active'}
      
      {param: 'transport.total_trips', label: 'Total Precinct Trips'}
      {param: 'transport.trips_car_driver'}
      {param: 'transport.trips_car_passenger'}
      {param: 'transport.trips_car_transit'}
      {param: 'transport.trips_car_active'}
      {param: 'transport.total_trips_year'}
      {param: 'transport.trips_car_driver_year'}
      {param: 'transport.trips_car_passenger_year'}
      {param: 'transport.trips_car_transit_year'}
      {param: 'transport.trips_car_active_year'}
    ]
