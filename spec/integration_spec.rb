# frozen_string_literal: true

require 'spec_helper'
require 'timecop'
require './models/station'

describe 'integration tests' do
  let(:config_hash) do
    {
      'stationId' => 'EV_STATION_PARIS_15',
      'gridCapacity' => 350, # kW
      'chargers' => [
        { 'id' => 'CP001', 'maxPower' => 200, 'connectors' => 2 },
        { 'id' => 'CP002', 'maxPower' => 200, 'connectors' => 2 },
        { 'id' => 'CP003', 'maxPower' => 300, 'connectors' => 2 }
      ],
      'battery' => {
        'initialCapacity' => 200, # kWh
        'power' => 100 # kW, max Charge and discharge power
      }
    }
  end
  let(:station) { Station.from_hash(config_hash) }

  describe 'one day in life of charging station' do
    it 'should adapt to the demand while respecting grid capacity' do
      start = Time.now
      Timecop.freeze(start)
      session1 = station.start_session(charger_id: 'CP001', connector_id: 0, vehicule_max_power: 200)
      session2 = station.start_session(charger_id: 'CP002', connector_id: 0, vehicule_max_power: 200)

      expect(station.find_session!(session1.id).allocated_power.round).to eq(200)
      expect(station.find_session!(session2.id).allocated_power.round).to eq(200)

      Timecop.travel(start + 3600)
      # Testing power updates
      station.power_update(session_id: session1.id, consumed_power: 200, vehicule_max_power: 100)
      station.power_update(session_id: session2.id, consumed_power: 200, vehicule_max_power: 100)

      expect(station.find_session!(session1.id).consumed_power).to eq(200)
      expect(station.find_session!(session2.id).consumed_power).to eq(200)

      # Checking that the battery was used to complete the missing 50kW for one hour,
      # leading to a 50kWh drop.
      expect(station.battery.current_capacity.round).to eq(150)

      session3 = station.start_session(charger_id: 'CP003', connector_id: 0, vehicule_max_power: 300)

      # Checking that max power is distributed evenly
      expect(station.find_session!(session1.id).allocated_power.round).to eq(100)
      expect(station.find_session!(session2.id).allocated_power.round).to eq(100)
      expect(station.find_session!(session3.id).allocated_power.round).to eq(250)

      station.stop_session(session_id: session1.id, consumed_energy: 100)

      expect(station.find_session!(session2.id).allocated_power).to eq(100)
      expect(station.find_session!(session3.id).allocated_power).to eq(300)

      station.stop_session(session_id: session2.id, consumed_energy: 100)

      Timecop.travel(start + 7200)
      station.power_update(session_id: session3.id, consumed_power: 200, vehicule_max_power: 200)

      # Testing that the battery is charged from the grid back to its initial capacity
      expect(station.battery.current_capacity.round).to eq(200)
    end
  end
end
