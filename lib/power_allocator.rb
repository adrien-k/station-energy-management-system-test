# frozen_string_literal: true

class PowerAllocator
  # Accepts an array of charger nodes with id, max_power and sessions children with each their own max_power;
  # along with the maximum power available
  # ex:
  # chargers = [
  #   {
  #     id: "CP001",
  #     max_power: 300,
  #     sessions: [
  #       { id: "uuid1", max_power: 100 },
  #       { id: "uuid2", max_power: 400 },
  #     ]
  #   ]}
  # ]
  #
  # Returns a hash of optimally allocated power for each connector node.
  # Ex:
  # {
  #   "uuid1" => 100,
  #   "uuid2" => 200,
  # }
  #
  def self.allocate(chargers, available_power)
    # Traverse the tree once to calculate the maximum power each session can receive
    # given the chargers limits and the session's vehicle max accepted power.
    session_nodes = gather_sessions_with_max_power_constraints(chargers)

    # Now that we know the maximum power each session can receive
    # we allocate the available power evenly while respecting the constraints.
    balance_power(available_power, session_nodes)
  end

  # For each sessions, this returns the max_power it can receive given:
  # - the session's vehicle max accepted power
  # - the charger max_power
  # - other sessions and their max_power, as the charger's maximum power is evenly distributed
  #   when it is a limiting factor.
  def self.gather_sessions_with_max_power_constraints(chargers)
    chargers.map do |charger|
      max_power_per_session = balance_power(charger[:max_power], charger[:sessions])

      charger[:sessions].map do |session|
        {
          id: session[:id],
          max_power: max_power_per_session[session[:id]]
        }
      end
    end.flatten
  end

  # Balances the available power evenly across nodes that each have a :max_power
  # and :id properties.
  # When a node has filled its max_power with less than its fair share, the remaining available
  # power is distributed evenly across the remaining nodes.
  #
  # Example:
  # available_powers = 100
  # nodes = [
  #   { id: "node1", max_power: 50 },
  #   { id: "node2", max_power: 50 },
  #   { id: "node3", max_power: 10 }
  # ]
  # Returns:
  # { "node1" => 45, "node2" => 45, "node3" => 10 }
  def self.balance_power(available_power, nodes)
    power_per_node = Hash.new(0)
    remaining_power = available_power

    loop do
      unfilled_nodes = nodes.select { |node| power_per_node[node[:id]] < node[:max_power] }
      # All nodes have their max_power filled.
      break if unfilled_nodes.empty?

      power_split_per_node = (remaining_power.to_f / unfilled_nodes.count).ceil

      # No more power to distribute (or partial kW, which we skip for simplicity, see #ceil above)
      break if power_split_per_node <= 0

      unfilled_nodes.each do |node|
        added_power = [power_split_per_node, node[:max_power] - power_per_node[node[:id]]].min
        power_per_node[node[:id]] += added_power
        remaining_power -= added_power
      end
    end

    power_per_node
  end
end
