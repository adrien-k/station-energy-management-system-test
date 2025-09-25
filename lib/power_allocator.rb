# frozen_string_literal: true

class PowerAllocator
  # Accepts an array of charger nodes with id, max_power and connectors children with each their own max_power; along with the maximum power available
  # ex:
  # [
  #   {
  #     id: "CP001", max_power: 300, sessions: [
  #       { id: "uuid1", max_power: 100 },
  #       { id: "uuid2", max_power: 400 },
  #     ]
  #   ]}
  # ]
  # Returns a hash of optimally allocated power for each connector node.
  # Ex:
  # {
  #   "uuid1" => 100,
  #   "uuid2" => 200,
  # }
  #
  def self.allocate(chargers, available_power)
    # Traverse the tree once to calculate the maximum power each session can receive
    # given the chargers limits and the sessions max power.
    session_allocations = init_session_allocations(chargers)
    remaining_power = available_power

    # Now that we know the maximum power each session can receive given the vehicles and charger constraints,
    # we allocate the available power evenly while respecting the constraints.
    #
    # Some sessions may actually use less than their even share of power and the rest can be distributed evenly
    # across the remaining sessions.
    # We loop until we have allocated all the power or there are no more sessions with remaining power capacity.
    loop do
      unfilled_sessions = session_allocations.values.select do |session|
        session[:allocated_power] < session[:cap_power]
      end

      break if unfilled_sessions.empty?

      global_share_per_session = (remaining_power.to_f / unfilled_sessions.count).ceil

      break if global_share_per_session.zero? # we only allocate full kW incremens

      unfilled_sessions.each do |session|
        added_power = [global_share_per_session, session[:cap_power] - session[:allocated_power]].min
        session[:allocated_power] += added_power
        remaining_power -= added_power
      end
    end

    session_allocations.transform_values { |session| session[:allocated_power] }
  end

  def self.init_session_allocations(chargers)
    session_allocations = {}

    chargers.map do |charger|
      if charger[:max_power] < charger[:sessions].sum { |session| session[:max_power] }
        # When multiple connectors are used on a charger and the total power acceptable
        # by all vehicles is superior than the charger max power,
        # each connector only gets an even share of the power at the maximum.
        # Ex: 300kW charger with 2x200kW connectors, each connector gets 150kW max.
        #     With 100KW/300KW, they get 100kW/150kW even if they ideally could get 100/200kW.
        #
        # TODO: this could be improved if we applied the rebalancing algorithm above to the whole tree.
        max_share_per_session = charger[:max_power].to_f / charger[:sessions].count
      end
      charger[:sessions].each do |session|
        session_allocations[session[:id]] = {
          allocated_power: 0,
          cap_power: max_share_per_session ? [max_share_per_session, session[:max_power]].min : session[:max_power]
        }
      end
    end

    session_allocations
  end
end
