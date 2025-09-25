# frozen_string_literal: true

require 'securerandom'

class Session
  def initialize(connector, vehicule_max_power:)
    @id = SecureRandom.uuid
    @connector = connector
    @vehicule_max_power = vehicule_max_power
    @consumed_power = 0
    @allocated_power = 0
  end

  #
  # Accessors
  #
  attr_accessor :allocated_power
  attr_reader :id, :vehicule_max_power, :consumed_power, :connector

  def station
    @connector.station
  end

  def charger
    @connector.charger
  end

  def stop(consumed_energy:)
    @consumed_power += consumed_energy
    @connector.clear_session
    station.reallocate_power!
  end

  def update_power(consumed_power:, vehicule_max_power:)
    @vehicule_max_power = vehicule_max_power
    @consumed_power += consumed_power
    station.reallocate_power!
  end
end
