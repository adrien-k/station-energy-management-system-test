# frozen_string_literal: true

require "spec_helper"
require "./lib/power_allocator"

describe PowerAllocator do
  describe ".allocate!" do
    it "distributes available power evenly " do
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

    it "distributes power according to vehicle max power" do
      expect(
        PowerAllocator.allocate(
          [
            {
              id: "CP001",
              max_power: 500,
              sessions: [
                { id: "session1", max_power: 150 },
                { id: "session2", max_power: 50 }
              ]
            }
          ],
          500
        )
      ).to eq(
        {
          "session1" => 150,
          "session2" => 50
        }
      )
    end

    it "distributes power effectively across connectors and respects charger limit" do
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
          "session1" => 200,
          "session2" => 100
        }
      )
    end


    it "can distribute effectively over multiple chargers" do
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
          300)
      ).to eq(
        "session1" => 150,
        "session2" => 50,
        # Session 3 and 4 have maxed out the charger power,
        # so session 1 can get the remaining grid power.
        "session3" => 50,
        "session4" => 50
      )
    end
  end
end
