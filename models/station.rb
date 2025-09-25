require "./models/charger"
require "./models/battery"
require "./errors"

class Station
  POWER_REFRESH_INTERVAL_SECONDS = 60 # 1.minute

  def self.from_hash(config_hash)
    new(config_hash["stationId"], config_hash)
  end

  def initialize(id, config_hash)
    @id = id
    @grid_capacity = config_hash["gridCapacity"]

    @chargers_by_id = config_hash["chargers"].to_h do |charger_config|
      charger_id = charger_config["id"]
      [ charger_id, Charger.new(self, charger_id, charger_config) ]
    end

    @battery = config_hash["battery"] && Battery.new(self, config_hash["battery"])

    @sessions_by_id = {}
  end

  #
  # Accessors
  #
  attr_reader :battery, :grid_capacity

  def chargers
    @chargers_by_id.values
  end

  def sessions
    @sessions_by_id.values
  end

  def clear_session(session_id)
    @sessions_by_id.delete(session_id)
  end

  def reallocate_power!
    power_tree = sessions.group_by(&:charger).map do |charger, sessions|
      {
        id: charger.id,
        max_power: charger.max_power,
        sessions: sessions.map do |session|
          {
            id: session.id,
            max_power: session.vehicule_max_power
          }
        end
      }
    end

    power_per_session_id = PowerAllocator.allocate(power_tree, available_power)

    allocated_power = power_per_session_id.values.sum

    # TODO: could be extracted elsewhere.
    if battery
      # This will charge (negative value) or discharge (positive value) the battery depending on
      # how much power was allocated compared to the grid capacity
      battery_power = allocated_power - grid_capacity

      if battery_power < 0 # Charging the battery from the grid
        # we limit the power we take from the grid to the battery max power
        if battery_power.abs > battery.max_power
          battery_power = -battery.max_power
        end

        if battery.full?
          battery_power = 0
        end
      end
      battery.allocate_power!(battery_power)
    end

    sessions.each do |session|
      session.allocated_power = power_per_session_id[session.id]
    end
  end


  # Calculate total available power from battery and grid
  def available_power
    grid_capacity + (battery&.max_available_power || 0)
  end

  def start_session(charger_id:, connector_id:, vehicule_max_power:)
    charger = find_charger!(charger_id)
    connector = charger.find_connector!(connector_id)

    session = connector.create_session(vehicule_max_power:)
    @sessions_by_id[session.id] = session

    reallocate_power!

    session
  end

  def stop_session(session_id:, consumed_energy:)
    session = find_session!(session_id)
    session.stop(consumed_energy:)
    session
  end

  def power_update(session_id:, consumed_power:, vehicule_max_power:)
    session = find_session!(session_id)
    session.update_power(consumed_power:, vehicule_max_power:)

    session
  end

  #
  ## Finders
  #
  def find_charger!(charger_id)
    @chargers_by_id[charger_id] || raise(NotFoundError, "Charger #{charger_id} does not exist")
  end

  def find_session!(session_id)
    @sessions_by_id[session_id] || raise(NotFoundError, "Session #{session_id} does not exist")
  end
end
