# frozen_string_literal: true

require "spec_helper"
require "./lib/power_allocator"

describe PowerAllocator do
  describe ".allocate!" do
    it "distributes power evenly" do
      expect(
        PowerAllocator.allocate(
          [
            {
              id: "CP001",
              max_power: 300,
              sessions: [
                { id: "session1", max_power: 150 },
                { id: "session2", max_power: 150 }
              ]
            }
          ],
          200
        )
      ).to eq(
        {
          "session1" => 100,
          "session2" => 100
        }
      )
    end

    it "distributes power evenly across connectors when exceeding the charger limit" do
      expect(
        PowerAllocator.allocate(
          [
            {
              id: "CP001",
              max_power: 300,
              sessions: [
                { id: "session1", max_power: 400 },
                { id: "session2", max_power: 100 }
              ]
            }
          ],
          400
        )
      ).to eq(
        {
          # TODO: this is sub-optimal as we could allocate 200/100 kW.
          # that requires a more complex tree-balancing algorithm.
          "session1" => 150,
          "session2" => 100
        }
      )
    end

    it "respects charger limits" do
      expect(
        PowerAllocator.allocate(
          [
            {
              id: "CP001",
              max_power: 100,
              sessions: [
                { id: "session1", max_power: 150 },
                { id: "session2", max_power: 150 }
              ]
            }
          ],
          200)
      ).to eq(
        "session1" => 50,
        "session2" => 50
      )
    end

    it "can distribute non-evenly" do
      expect(
        PowerAllocator.allocate(
          [
            {
              id: "CP001",
              max_power: 300,
              sessions: [
                { id: "session1", max_power: 200 },
                { id: "session2", max_power: 50 }
              ]
            }
          ],
          200)
      ).to eq(
        "session1" => 150,
        "session2" => 50
      )
    end

    it "can distribute over multiple chargers" do
      expect(
        PowerAllocator.allocate(
          [
            {
              id: "CP001",
              max_power: 300,
              sessions: [
                { id: "session1", max_power: 200 },
                { id: "session2", max_power: 50 }
              ]
            },
            {
              id: "CP001",
              max_power: 100,
              sessions: [
                { id: "session3", max_power: 200 },
                { id: "session4", max_power: 50 }
              ]
            }
          ],
          400)
      ).to eq(
        "session1" => 200,
        "session2" => 50,
        "session3" => 50,
        "session4" => 50
      )
    end
  end
end
