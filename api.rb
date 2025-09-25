#! /usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'json'
require './models/station'
require './errors'

# Load configuration and initialize station
config = JSON.parse(File.read('config.json'))
$station = Station.from_hash(config)

# Enable JSON parsing for request bodies
set :json_encoder, :to_json
# Shows realistic api errors in dev mode
set :show_exceptions, :after_handler

set :bind, '0.0.0.0'

# Error handling
error ClientError do |e|
  status 400
  { error: e.message }.to_json
end

error NotFoundError do |e|
  status 404
  { error: e.message }.to_json
end

error StandardError do |e|
  status 500
  { error: "Internal server error: #{e.message}" }.to_json
end

# Get real-time station status and power allocation
get '/station/status' do
  content_type :json

  active_sessions = $station.sessions.map do |session|
    {
      sessionId: session.id,
      chargerId: session.charger.id,
      connectorId: session.connector.id
    }
  end

  power_allocation = $station.chargers.map do |charger|
    charger_sessions = $station.sessions.select { |s| s.charger.id == charger.id }
    {
      chargerId: charger.id,
      maxPower: charger.max_power,
      sessions: charger_sessions.map do |session|
        {
          sessionId: session.id,
          allocatedPower: session.allocated_power,
          vehicleMaxPower: session.vehicule_max_power,
          consumedPower: session.consumed_power
        }
      end
    }
  end

  {
    activeSessions: active_sessions,
    powerAllocation: power_allocation,
    availablePower: $station.available_power,
    gridCapacity: $station.grid_capacity,
    battery: if $station.battery
               {
                 maxPower: $station.battery.max_power,
                 currentCapacity: $station.battery.current_capacity,
                 maxAvailablePower: $station.battery.max_available_power,
                 allocatedPower: $station.battery.allocated_power
               }
             end
  }.to_json
end

# Start a new charging session
post '/sessions' do
  content_type :json

  request_body = JSON.parse(request.body.read)
  charger_id = request_body['chargerId']
  connector_id = request_body['connectorId']
  vehicle_max_power = request_body['vehicleMaxPower']

  # Validate required parameters
  if charger_id.nil? || connector_id.nil? || vehicle_max_power.nil?
    raise ClientError, 'Missing required parameters: chargerId, connectorId, vehicleMaxPower'
  end

  # Validate vehicle_max_power is positive
  raise ClientError, 'vehicleMaxPower must be positive' if vehicle_max_power <= 0

  session = $station.start_session(
    charger_id:,
    connector_id:,
    vehicule_max_power: vehicle_max_power
  )

  {
    sessionId: session.id,
    allocatedPower: session.allocated_power
  }.to_json
end

# Stop a charging session
post '/sessions/:session_id/stop' do
  content_type :json

  session_id = params[:session_id]
  request_body = JSON.parse(request.body.read)
  consumed_energy = request_body['consumedEnergy']

  session = $station.stop_session(session_id:, consumed_energy:)

  {
    success: true,
    sessionId: session.id,
    totalConsumedEnergy: session.consumed_power
  }.to_json
end

# Update power consumption for a session
post '/sessions/:session_id/power-update' do
  content_type :json

  session_id = params[:session_id]
  request_body = JSON.parse(request.body.read)
  consumed_power = request_body['consumedPower']
  vehicle_max_power = request_body['vehicleMaxPower']

  # Validate required parameters
  if consumed_power.nil? || vehicle_max_power.nil?
    raise ClientError, 'Missing required parameters: consumedPower, vehicleMaxPower'
  end

  # Validate consumed_power is non-negative
  raise ClientError, 'consumedPower must be non-negative' if consumed_power.negative?

  # Validate vehicle_max_power is positive
  raise ClientError, 'vehicleMaxPower must be positive' if vehicle_max_power <= 0

  session = $station.power_update(
    session_id:,
    consumed_power:,
    vehicule_max_power: vehicle_max_power
  )

  {
    sessionId: session.id,
    allocatedPower: session.allocated_power,
    consumedPower: session.consumed_power
  }.to_json
end
