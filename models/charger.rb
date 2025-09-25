# frozen_string_literal: true

require './errors'
require './models/connector'

class Charger
  def initialize(station, id, charger_hash)
    @id = id
    @station = station
    @max_power = charger_hash['maxPower']
    @connectors_by_id = charger_hash['connectors'].times.to_h do |connector_id|
      [ connector_id, Connector.new(self, connector_id) ]
    end
  end

  # Accessors
  attr_reader :id, :station, :max_power

  def connectors
    @connectors_by_id.values
  end

  def connectors
    @connectors_by_id.values
  end

  def find_connector!(connector_id)
    @connectors_by_id[connector_id] || raise(NotFoundError,
                                             "Connector #{connector_id} does not exist for charger #{@id}")
  end
end
