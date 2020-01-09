# frozen_string_literal: true

require 'spec_helper'

module QueueBus
  describe Dispatch do
    it 'should not start with any applications' do
      expect(Dispatch.new('d').subscriptions.size).to eq(0)
    end

    it 'should register code to run and execute it' do
      dispatch = Dispatch.new('d')
      dispatch.subscribe('my_event') do |attrs|
        Runner1.run(attrs)
      end
      sub = dispatch.subscriptions.key('my_event')
      expect(sub.send(:executor).is_a?(Proc)).to eq(true)

      expect(Runner.value).to eq(0)
      dispatch.execute('my_event', 'bus_event_type' => 'my_event', 'ok' => true)
      expect(Runner1.value).to eq(1)
      expect(Runner1.attributes).to eq('bus_event_type' => 'my_event', 'ok' => true)
    end

    it 'should not crash if not there' do
      expect do
        Dispatch.new('d').execute('fdkjh', 'bus_event_type' => 'fdkjh')
      end.not_to raise_error
    end

    describe 'Top Level' do
      before(:each) do
        QueueBus.dispatch('testit') do
          subscribe 'event1' do |attributes|
            Runner2.run(attributes)
          end

          subscribe 'event2' do
            Runner2.run({})
          end

          high 'event3' do
            Runner2.run({})
          end

          low /^patt.+ern/ do
            Runner.run({})
          end
        end
      end

      it 'should register and run' do
        expect(Runner2.value).to eq(0)
        QueueBus.dispatcher_execute('testit', 'event2', 'bus_event_type' => 'event2')
        expect(Runner2.value).to eq(1)
        QueueBus.dispatcher_execute('testit', 'event1', 'bus_event_type' => 'event1')
        expect(Runner2.value).to eq(2)
        QueueBus.dispatcher_execute('testit', 'event1', 'bus_event_type' => 'event1')
        expect(Runner2.value).to eq(3)
      end

      it 'should return the subscriptions' do
        dispatcher = QueueBus.dispatcher_by_key('testit')
        subs = dispatcher.subscriptions.all
        tuples = subs.collect { |sub| [sub.key, sub.queue_name] }
        expect(tuples).to match_array([%w[event1 testit_default],
                                       %w[event2 testit_default],
                                       %w[event3 testit_high],
                                       ['(?-mix:^patt.+ern)', 'testit_low']])
      end
    end
  end
end
