require "./errors"
require "./models/session"

class Connector
  def initialize(charger, id)
    @charger = charger
    @id = id
    @session = nil
  end
  #
  # Accessors
  #
  attr_reader :id, :session, :charger
  def station
    @charger.station
  end

  def available?
    @session.nil?
  end

  def create_session(vehicule_max_power:)
    raise ClientError, "Connector already in use" unless available?

    @session = Session.new(self, vehicule_max_power:)
    @session
  end

  def clear_session
    station.clear_session(@session.id)
    @session = nil
  end
end
