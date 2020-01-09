# frozen_string_literal: true

require 'spec_helper'

describe QueueBus::Subscriber do
  let(:attributes) { { 'x' => 'y' } }
  let(:bus_attrs) { { 'bus_driven_at' => Time.now.to_i } }

  before(:each) do
    class SubscriberTest1
      include QueueBus::Subscriber
      @queue = 'myqueue'

      application :my_thing
      subscribe :thing_filter, x: 'y'
      subscribe :event_sub

      def event_sub(attributes)
        QueueBus::Runner1.run(attributes)
      end

      def thing_filter(attributes)
        QueueBus::Runner2.run(attributes)
      end
    end

    class SubscriberTest2
      include QueueBus::Subscriber
      application :test2
      subscribe :test2, 'value' => :present
      transform :make_an_int

      def self.make_an_int(attributes)
        attributes['value'].to_s.length
      end

      def test2(int)
        QueueBus::Runner1.run('transformed' => int)
      end
    end

    module SubModule
      class SubscriberTest3
        include QueueBus::Subscriber

        subscribe_queue :sub_queue1, :test3, bus_event_type: 'the_event'
        subscribe_queue :sub_queue2, :the_event
        subscribe :other, bus_event_type: 'other_event'

        def test3(attributes)
          QueueBus::Runner1.run(attributes)
        end

        def the_event(attributes)
          QueueBus::Runner2.run(attributes)
        end
      end

      class SubscriberTest4
        include QueueBus::Subscriber

        subscribe_queue :sub_queue1, :test4
      end
    end

    Timecop.freeze
    QueueBus::TaskManager.new(false).subscribe!
  end

  after(:each) do
    Timecop.return
  end

  it 'should have the application' do
    expect(SubscriberTest1.app_key).to eq('my_thing')
    expect(SubModule::SubscriberTest3.app_key).to eq('sub_module')
    expect(SubModule::SubscriberTest4.app_key).to eq('sub_module')
  end

  it 'should be able to transform the attributes' do
    dispatcher = QueueBus.dispatcher_by_key('test2')
    all = dispatcher.subscriptions.all
    expect(all.size).to eq(1)

    sub = all.first
    expect(sub.queue_name).to eq('test2_default')
    expect(sub.class_name).to eq('SubscriberTest2')
    expect(sub.key).to eq('SubscriberTest2.test2')
    expect(sub.matcher.filters).to eq('value' => 'bus_special_value_present')

    QueueBus::Driver.perform(attributes.merge('bus_event_type' => 'something2', 'value' => 'nice'))

    hash = JSON.parse(QueueBus.redis { |redis| redis.lpop('queue:test2_default') })
    expect(hash['class']).to eq('QueueBus::Worker')
    expect(hash['args'].size).to eq(1)
    expect(JSON.parse(hash['args'].first)).to eq({ 'bus_class_proxy' => 'SubscriberTest2', 'bus_rider_app_key' => 'test2', 'bus_rider_sub_key' => 'SubscriberTest2.test2', 'bus_rider_queue' => 'test2_default', 'bus_rider_class_name' => 'SubscriberTest2',
                                                   'bus_event_type' => 'something2', 'value' => 'nice', 'x' => 'y' }.merge(bus_attrs))

    expect(QueueBus::Runner1.value).to eq(0)
    expect(QueueBus::Runner2.value).to eq(0)
    QueueBus::Util.constantize(hash['class']).perform(*hash['args'])
    expect(QueueBus::Runner1.value).to eq(1)
    expect(QueueBus::Runner2.value).to eq(0)

    expect(QueueBus::Runner1.attributes).to eq('transformed' => 4)

    QueueBus::Driver.perform(attributes.merge('bus_event_type' => 'something2', 'value' => '12'))

    hash = JSON.parse(QueueBus.redis { |redis| redis.lpop('queue:test2_default') })
    expect(hash['class']).to eq('QueueBus::Worker')
    expect(hash['args'].size).to eq(1)
    expect(JSON.parse(hash['args'].first)).to eq({ 'bus_class_proxy' => 'SubscriberTest2', 'bus_rider_app_key' => 'test2', 'bus_rider_sub_key' => 'SubscriberTest2.test2', 'bus_rider_queue' => 'test2_default', 'bus_rider_class_name' => 'SubscriberTest2',
                                                   'bus_event_type' => 'something2', 'value' => '12', 'x' => 'y' }.merge(bus_attrs))

    expect(QueueBus::Runner1.value).to eq(1)
    expect(QueueBus::Runner2.value).to eq(0)
    QueueBus::Util.constantize(hash['class']).perform(*hash['args'])
    expect(QueueBus::Runner1.value).to eq(2)
    expect(QueueBus::Runner2.value).to eq(0)

    expect(QueueBus::Runner1.attributes).to eq('transformed' => 2)
  end

  it 'should put in a different queue' do
    dispatcher = QueueBus.dispatcher_by_key('sub_module')
    all = dispatcher.subscriptions.all
    expect(all.size).to eq(4)

    sub = all.select { |s| s.key == 'SubModule::SubscriberTest3.test3' }.first
    expect(sub.queue_name).to eq('sub_queue1')
    expect(sub.class_name).to eq('SubModule::SubscriberTest3')
    expect(sub.key).to eq('SubModule::SubscriberTest3.test3')
    expect(sub.matcher.filters).to eq('bus_event_type' => 'the_event')

    sub = all.select { |s| s.key == 'SubModule::SubscriberTest3.the_event' }.first
    expect(sub.queue_name).to eq('sub_queue2')
    expect(sub.class_name).to eq('SubModule::SubscriberTest3')
    expect(sub.key).to eq('SubModule::SubscriberTest3.the_event')
    expect(sub.matcher.filters).to eq('bus_event_type' => 'the_event')

    sub = all.select { |s| s.key == 'SubModule::SubscriberTest3.other' }.first
    expect(sub.queue_name).to eq('sub_module_default')
    expect(sub.class_name).to eq('SubModule::SubscriberTest3')
    expect(sub.key).to eq('SubModule::SubscriberTest3.other')
    expect(sub.matcher.filters).to eq('bus_event_type' => 'other_event')

    sub = all.select { |s| s.key == 'SubModule::SubscriberTest4.test4' }.first
    expect(sub.queue_name).to eq('sub_queue1')
    expect(sub.class_name).to eq('SubModule::SubscriberTest4')
    expect(sub.key).to eq('SubModule::SubscriberTest4.test4')
    expect(sub.matcher.filters).to eq('bus_event_type' => 'test4')

    QueueBus::Driver.perform(attributes.merge('bus_event_type' => 'the_event'))

    hash = JSON.parse(QueueBus.redis { |redis| redis.lpop('queue:sub_queue1') })
    expect(hash['class']).to eq('QueueBus::Worker')
    expect(hash['args'].size).to eq(1)
    expect(JSON.parse(hash['args'].first)).to eq({ 'bus_class_proxy' => 'SubModule::SubscriberTest3', 'bus_rider_app_key' => 'sub_module', 'bus_rider_sub_key' => 'SubModule::SubscriberTest3.test3', 'bus_rider_queue' => 'sub_queue1', 'bus_rider_class_name' => 'SubModule::SubscriberTest3',
                                                   'bus_event_type' => 'the_event', 'x' => 'y' }.merge(bus_attrs))

    expect(QueueBus::Runner1.value).to eq(0)
    expect(QueueBus::Runner2.value).to eq(0)
    QueueBus::Util.constantize(hash['class']).perform(*hash['args'])
    expect(QueueBus::Runner1.value).to eq(1)
    expect(QueueBus::Runner2.value).to eq(0)

    hash = JSON.parse(QueueBus.redis { |redis| redis.lpop('queue:sub_queue2') })
    expect(hash['class']).to eq('QueueBus::Worker')
    expect(hash['args'].size).to eq(1)
    expect(JSON.parse(hash['args'].first)).to eq({ 'bus_class_proxy' => 'SubModule::SubscriberTest3', 'bus_rider_app_key' => 'sub_module', 'bus_rider_sub_key' => 'SubModule::SubscriberTest3.the_event', 'bus_rider_queue' => 'sub_queue2', 'bus_rider_class_name' => 'SubModule::SubscriberTest3',
                                                   'bus_event_type' => 'the_event', 'x' => 'y' }.merge(bus_attrs))

    expect(QueueBus::Runner1.value).to eq(1)
    expect(QueueBus::Runner2.value).to eq(0)
    QueueBus::Util.constantize(hash['class']).perform(*hash['args'])
    expect(QueueBus::Runner1.value).to eq(1)
    expect(QueueBus::Runner2.value).to eq(1)
  end

  it 'should subscribe to default and attributes' do
    dispatcher = QueueBus.dispatcher_by_key('my_thing')
    all = dispatcher.subscriptions.all

    sub = all.select { |s| s.key == 'SubscriberTest1.event_sub' }.first
    expect(sub.queue_name).to eq('myqueue')
    expect(sub.class_name).to eq('SubscriberTest1')
    expect(sub.key).to eq('SubscriberTest1.event_sub')
    expect(sub.matcher.filters).to eq('bus_event_type' => 'event_sub')

    sub = all.select { |s| s.key == 'SubscriberTest1.thing_filter' }.first
    expect(sub.queue_name).to eq('myqueue')
    expect(sub.class_name).to eq('SubscriberTest1')
    expect(sub.key).to eq('SubscriberTest1.thing_filter')
    expect(sub.matcher.filters).to eq('x' => 'y')

    QueueBus::Driver.perform(attributes.merge('bus_event_type' => 'event_sub'))
    expect(QueueBus.redis { |redis| redis.smembers('queues') }).to match_array(['myqueue'])

    pop1 = JSON.parse(QueueBus.redis { |redis| redis.lpop('queue:myqueue') })
    pop2 = JSON.parse(QueueBus.redis { |redis| redis.lpop('queue:myqueue') })

    if JSON.parse(pop1['args'].first)['bus_rider_sub_key'] == 'SubscriberTest1.thing_filter'
      hash1 = pop1
      hash2 = pop2
    else
      hash1 = pop2
      hash2 = pop1
    end

    expect(hash1['class']).to eq('QueueBus::Worker')
    expect(JSON.parse(hash1['args'].first)).to eq({ 'bus_class_proxy' => 'SubscriberTest1', 'bus_rider_app_key' => 'my_thing', 'bus_rider_sub_key' => 'SubscriberTest1.thing_filter', 'bus_rider_queue' => 'myqueue', 'bus_rider_class_name' => 'SubscriberTest1',
                                                    'bus_event_type' => 'event_sub', 'x' => 'y' }.merge(bus_attrs))

    expect(QueueBus::Runner1.value).to eq(0)
    expect(QueueBus::Runner2.value).to eq(0)
    QueueBus::Util.constantize(hash1['class']).perform(*hash1['args'])
    expect(QueueBus::Runner1.value).to eq(0)
    expect(QueueBus::Runner2.value).to eq(1)

    expect(hash2['class']).to eq('QueueBus::Worker')
    expect(hash2['args'].size).to eq(1)
    expect(JSON.parse(hash2['args'].first)).to eq({ 'bus_class_proxy' => 'SubscriberTest1', 'bus_rider_app_key' => 'my_thing', 'bus_rider_sub_key' => 'SubscriberTest1.event_sub', 'bus_rider_queue' => 'myqueue', 'bus_rider_class_name' => 'SubscriberTest1',
                                                    'bus_event_type' => 'event_sub', 'x' => 'y' }.merge(bus_attrs))

    expect(QueueBus::Runner1.value).to eq(0)
    expect(QueueBus::Runner2.value).to eq(1)
    QueueBus::Util.constantize(hash2['class']).perform(*hash2['args'])
    expect(QueueBus::Runner1.value).to eq(1)
    expect(QueueBus::Runner2.value).to eq(1)

    QueueBus::Driver.perform(attributes.merge('bus_event_type' => 'event_sub_other'))
    expect(QueueBus.redis { |redis| redis.smembers('queues') }).to match_array(['myqueue'])

    hash = JSON.parse(QueueBus.redis { |redis| redis.lpop('queue:myqueue') })
    expect(hash['class']).to eq('QueueBus::Worker')
    expect(hash['args'].size).to eq(1)
    expect(JSON.parse(hash['args'].first)).to eq({ 'bus_class_proxy' => 'SubscriberTest1', 'bus_rider_app_key' => 'my_thing', 'bus_rider_sub_key' => 'SubscriberTest1.thing_filter', 'bus_rider_queue' => 'myqueue', 'bus_rider_class_name' => 'SubscriberTest1',
                                                   'bus_event_type' => 'event_sub_other', 'x' => 'y' }.merge(bus_attrs))

    expect(QueueBus::Runner1.value).to eq(1)
    expect(QueueBus::Runner2.value).to eq(1)
    QueueBus::Util.constantize(hash['class']).perform(*hash['args'])
    expect(QueueBus::Runner1.value).to eq(1)
    expect(QueueBus::Runner2.value).to eq(2)

    QueueBus::Driver.perform({ 'x' => 'z' }.merge('bus_event_type' => 'event_sub_other'))
    expect(QueueBus.redis { |redis| redis.smembers('queues') }).to match_array(['myqueue'])

    expect(QueueBus.redis { |redis| redis.lpop('queue:myqueue') }).to be_nil
  end

  describe '.perform' do
    let(:attributes) { { 'bus_rider_sub_key' => 'SubscriberTest1.event_sub', 'bus_locale' => 'en', 'bus_timezone' => 'PST' } }
    it 'should call the method based on key' do
      expect_any_instance_of(SubscriberTest1).to receive(:event_sub)
      SubscriberTest1.perform(attributes)
    end
    it 'should set the timezone and locale if present' do
      expect(defined?(I18n)).to be_nil
      expect(Time.respond_to?(:zone)).to eq(false)

      stub_const('I18n', Class.new)
      expect(I18n).to receive(:locale=).with('en')
      expect(Time).to receive(:zone=).with('PST')

      expect_any_instance_of(SubscriberTest1).to receive(:event_sub)
      SubscriberTest1.perform(attributes)
    end
  end
end
