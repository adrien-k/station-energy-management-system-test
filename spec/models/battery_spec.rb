# frozen_string_literal: true

require 'spec_helper'
require 'timecop'
require './models/battery'

RSpec.describe Battery do
  let(:station) { double('station') }
  let(:battery_hash) do
    {
      'initialCapacity' => 100.0,
      'power' => 50.0
    }
  end
  let(:battery) { Battery.new(station, battery_hash) }

  describe '#allocate_power!' do
    it 'updates the allocated power' do
      expect { battery.allocate_power!(10) }.to change(battery, :allocated_power).to(10)
    end

    it 'updates the capacity based on the previously allocated power' do
      now = Time.now
      Timecop.freeze(now - 3600) do
        battery.allocate_power!(10)
        expect(battery.current_capacity).to eq(100)
      end

      Timecop.freeze(now) do
        battery.allocate_power!(20)
        expect(battery.current_capacity).to eq(90)
      end
    end

    it 'can also charge the battery up to its initial capacity' do
      now = Time.now
      Timecop.freeze(now - 7200) do
        battery.allocate_power!(50)
        expect(battery.current_capacity).to eq(100)
      end

      Timecop.freeze(now - 3600) do
        battery.allocate_power!(-10)
        expect(battery.current_capacity).to eq(50)
      end

      Timecop.freeze(now) do
        battery.allocate_power!(0)
        expect(battery.current_capacity).to eq(60)
      end
    end

    it 'prevents allocating more power than the battery can sustain' do
      expect { battery.allocate_power!(60) }.to raise_error('Cannot allocate more power than the battery can sustain')
    end

    context 'with a drained battery' do
      let(:battery_hash) do
        {
          'initialCapacity' => 100,
          'power' => 100.0
        }
      end
      it 'prevents allocating power when battery is drained' do
        battery.instance_variable_set(:@capacity, 8)
        expect { battery.allocate_power!(100) }.to raise_error('Not enough capacity to allocate power')
      end
    end
  end
end
