# frozen_string_literal: true

require 'spec_helper'
require './models/station'
require './errors'

describe Station do
  let(:config_hash) do
    {
      'stationId' => 'EV_STATION_PARIS_15',
      'gridCapacity' => 400, # kW
      'chargers' => [
        { 'id' => 'CP001', 'maxPower' => 200, 'connectors' => 2 }, # 200 kW shared between the two connectors
        { 'id' => 'CP002', 'maxPower' => 200, 'connectors' => 2 },
        { 'id' => 'CP003', 'maxPower' => 300, 'connectors' => 2 }
      ],
      'battery' => {
        'initialCapacity' => 200, # kWh
        'power' => 100 # kW, max Charge and discharge power
      }
    }
  end

  describe 'initialization' do
    it 'should initialize a station with all information' do
      station = Station.from_hash(config_hash)
      expect(station).to be_a(Station)
      expect(station.chargers.map(&:id)).to eq(%w[CP001 CP002 CP003])
      expect(station.chargers.map(&:max_power)).to eq([200, 200, 300])
      expect(station.chargers.flat_map(&:connectors).count).to eq(6)

      expect(station.battery).to be_a(Battery)
      expect(station.battery.initial_capacity).to eq(200)
      expect(station.battery.max_power).to eq(100)
    end
  end

  describe 'start_session' do
    let(:station) { Station.from_hash(config_hash) }

    it 'should start a session on a connector' do
      session = station.start_session(charger_id: 'CP001', connector_id: 0, vehicule_max_power: 100)
      expect(session).to be_a(Session)
      expect(session.id).to be_a(String)
    end

    # Simple case here as there is a single vehicule and enough power in the station,
    # more tests in power_allocator_spec.rb
    it 'should return the allocated power' do
      session = station.start_session(charger_id: 'CP001', connector_id: 0, vehicule_max_power: 142)
      expect(session.allocated_power).to eq(142)
    end

    describe 'errors' do
      it 'should raise an error if the charger does not exist' do
        expect do
          station.start_session(charger_id: 'CP004', connector_id: 0, vehicule_max_power: 100)
        end.to raise_error(NotFoundError)
      end

      it 'should raise an error if the connector does not exist' do
        expect do
          station.start_session(charger_id: 'CP001', connector_id: 2, vehicule_max_power: 100)
        end.to raise_error(NotFoundError)
      end

      it 'should raise an error if the connector is already in use' do
        station.start_session(charger_id: 'CP001', connector_id: 0, vehicule_max_power: 100)
        expect do
          station.start_session(charger_id: 'CP001', connector_id: 0, vehicule_max_power: 100)
        end.to raise_error(ClientError)
      end
    end
  end

  describe 'stop_session' do
    let(:station) { Station.from_hash(config_hash) }
    let!(:session) { station.start_session(charger_id: 'CP001', connector_id: 0, vehicule_max_power: 100) }

    it 'should stop a session' do
      expect do
        station.stop_session(session_id: session.id, consumed_energy: 100)
      end.to change { station.sessions.count }.by(-1)
    end

    describe 'errors' do
      it 'should raise an error if the session does not exist' do
        expect { station.stop_session(session_id: 'invalid', consumed_energy: 100) }.to raise_error(NotFoundError)
      end

      it 'should raise an error if the session is already stopped' do
        station.stop_session(session_id: session.id, consumed_energy: 100)
        expect { station.stop_session(session_id: session.id, consumed_energy: 100) }.to raise_error(NotFoundError)
      end
    end
  end
end
