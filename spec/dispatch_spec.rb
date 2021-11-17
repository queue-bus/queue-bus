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

    describe '#on_heartbeat' do
      let(:dispatch) { Dispatch.new('heartbeat') }
      let(:event) { { bus_event_type: :heartbeat_minutes } }
      let(:event_name) { 'my-event' }

      it 'passes on the event' do
        dispatch.on_heartbeat event_name do |event|
          expect(event).to match hash_including('hour' => 1, 'minute' => 0)
        end

        dispatch.execute(event_name, 'hour' => 1, 'minute' => 0)
      end

      context 'when not declaring anything' do
        before do
          dispatch.on_heartbeat event_name do |_event|
            Runner2.run({})
          end
        end

        it 'runs on every heart beat' do
          (0..24).each do |hour|
            (0..60).each do |minute|
              expect do
                dispatch.execute(
                  event_name, event.merge('hour' => hour, 'minute' => minute)
                )
              end.to change(Runner2, :value).by(1)
            end
          end
        end
      end

      context 'when running on hour 8' do
        before do
          dispatch.on_heartbeat event_name, hour: 8 do |_event|
            Runner2.run({})
          end
        end

        it 'subscribes to hour 8' do
          expect(dispatch.subscriptions.all.first.matcher.filters)
            .to eq('bus_event_type' => 'heartbeat_minutes', 'hour' => '8')
        end
      end

      context 'when running on minute 4' do
        before do
          dispatch.on_heartbeat event_name, minute: 4 do |_event|
            Runner2.run({})
          end
        end

        it 'subscribes to minute 4' do
          expect(dispatch.subscriptions.all.first.matcher.filters)
            .to eq('bus_event_type' => 'heartbeat_minutes', 'minute' => '4')
        end
      end

      context 'when running on minute 4 and hour 8' do
        before do
          dispatch.on_heartbeat event_name, hour: 8, minute: 4 do |_event|
            Runner2.run({})
          end
        end

        it 'subscribes to minute 4 and hour 8' do
          expect(dispatch.subscriptions.all.first.matcher.filters)
            .to eq('bus_event_type' => 'heartbeat_minutes', 'minute' => '4', 'hour' => '8')
        end
      end

      context 'when running on wday 2' do
        before do
          dispatch.on_heartbeat event_name, wday: 2 do |_event|
            Runner2.run({})
          end
        end

        it 'subscribes to wday 2' do
          expect(dispatch.subscriptions.all.first.matcher.filters)
            .to eq('bus_event_type' => 'heartbeat_minutes', 'wday' => '2')
        end
      end

      context 'when declaring minute intervals' do
        before do
          dispatch.on_heartbeat event_name, minute_interval: 5 do |_event|
            Runner2.run({})
          end
        end

        it 'runs the runner when the minute buzzes (modulos to 5)' do
          (0..60).each do |minute|
            if minute % 5 == 0
              expect { dispatch.execute(event_name, event.merge('minute' => minute)) }
                .to change(Runner2, :value).by(1)
            else
              expect { dispatch.execute(event_name, event.merge('minute' => minute)) }
                .not_to change(Runner2, :value)
            end
          end
        end
      end

      context 'when declaring hour intervals' do
        before do
          dispatch.on_heartbeat event_name, hour_interval: 3 do |_event|
            Runner2.run({})
          end
        end

        it 'runs the runner when the hour fizzes (modulos to 3)' do
          (0..60).each do |hour|
            if hour % 3 == 0
              expect { dispatch.execute(event_name, event.merge('hour' => hour)) }
                .to change(Runner2, :value).by(1)
            else
              expect { dispatch.execute(event_name, event.merge('hour' => hour)) }
                .not_to change(Runner2, :value)
            end
          end
        end
      end

      context 'when declaring hour and minute intervals' do
        before do
          dispatch.on_heartbeat event_name, minute_interval: 5, hour_interval: 3 do |_event|
            Runner2.run({})
          end
        end

        it 'runs the runner when the time fizzbuzzes (modulos to 3 and 5)' do
          (0..24).each do |hour|
            (0..60).each do |minute|
              if hour % 3 == 0 && minute % 5 == 0
                expect do
                  dispatch.execute(
                    event_name, event.merge('hour' => hour, 'minute' => minute)
                  )
                end.to change(Runner2, :value).by(1)
              else
                expect do
                  dispatch.execute(
                    event_name, event.merge('hour' => hour, 'minute' => minute)
                  )
                end.not_to change(Runner2, :value)
              end
            end
          end
        end
      end
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
