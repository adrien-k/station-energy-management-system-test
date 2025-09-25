# frozen_string_literal: true

require './lib/power_allocator'
require './models/station'

class Battery
  def initialize(station, battery_hash)
    @station = station
    @initial_capacity = battery_hash['initialCapacity']
    @capacity = @initial_capacity
    @max_power = battery_hash['power']
    @last_capacity_update = Time.now
    @allocated_power = 0
  end

  # Accessors
  attr_reader :initial_capacity, :max_power, :capacity, :allocated_power

  # Allocate X kW of power from the battery
  # - positive value: using the battery to charge the vehicles.
  # - negative value: charging the battery from the grid.
  def allocate_power!(power)
    @capacity = current_capacity
    @last_capacity_update = Time.now

    # This applies both for charging and discharging
    raise 'Cannot allocate more power than the battery can sustain' if power.abs > max_power

    raise 'Not enough capacity to allocate power' if @capacity < minimum_capacity

    @allocated_power = power
  end

  def max_available_power
    return 0 if current_capacity < minimum_capacity

    @max_power
  end

  def full?
    current_capacity >= @initial_capacity
  end

  # Current capacity of the battery
  # Notes:
  # - this is an approximation as it does not account for battery degradation over time etc..
  def current_capacity
    consumed_or_accumulated_energy = @allocated_power * (Time.now - @last_capacity_update).to_f / 3600
    [@capacity - consumed_or_accumulated_energy, @initial_capacity].min
  end

  # To avoid draining the battery completly, we stop using the battery when it's below 10%
  # of its initial capacity.
  def minimum_capacity
    @initial_capacity * 0.1
  end
end
