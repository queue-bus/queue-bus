# frozen_string_literal: true

require 'spec_helper'

module QueueBus
  describe SubscriptionList do
    describe '.from_redis' do
      let(:mult) do
        { 'event_one' => { 'class' => 'MyClass', 'queue_name' => 'default', 'key' => 'event_one', 'matcher' => { 'bus_event_type' => 'event_one' } },
          'event_two' => { 'class' => 'MyClass', 'queue_name' => 'else', 'key' => 'event_two', 'matcher' => { 'bus_event_type' => 'event_two' } } }
      end

      it 'should return from attributes' do
        list = SubscriptionList.from_redis(mult)
        expect(list.size).to eq(2)
        one = list.key('event_one')
        two = list.key('event_two')

        expect(one.key).to eq('event_one')
        expect(one.key).to eq('event_one')
        expect(one.queue_name).to eq('default')
        expect(one.class_name).to eq('MyClass')
        expect(one.matcher.filters).to eq('bus_event_type' => 'event_one')

        expect(two.key).to eq('event_two')
        expect(two.key).to eq('event_two')
        expect(two.queue_name).to eq('else')
        expect(two.class_name).to eq('MyClass')
        expect(two.matcher.filters).to eq('bus_event_type' => 'event_two')
      end

      it 'raises an error if a subscription key already exists' do
        mult['event_two']['key'] = 'event_one'

        expect { SubscriptionList.from_redis(mult) }
          .to raise_error(RuntimeError)
      end
    end

    describe '#to_redis' do
      it 'should generate what to store' do
        list = SubscriptionList.new
        list.add(Subscription.new('default', 'key1', 'MyClass', 'bus_event_type' => 'event_one'))
        list.add(Subscription.new('else_ok', 'key2', 'MyClass', 'bus_event_type' => 'event_two'))

        hash = list.to_redis
        expect(hash).to eq('key1' => { 'queue_name' => 'default', 'key' => 'key1', 'class' => 'MyClass', 'matcher' => { 'bus_event_type' => 'event_one' } },
                           'key2' => { 'queue_name' => 'else_ok', 'key' => 'key2', 'class' => 'MyClass', 'matcher' => { 'bus_event_type' => 'event_two' } })
      end
    end
  end
end
