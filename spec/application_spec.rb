# frozen_string_literal: true

require 'spec_helper'

module QueueBus
  describe Application do
    describe '.all' do
      it 'should return empty array when none' do
        expect(Application.all).to eq([])
      end
      it 'should return registered applications when there are some' do
        Application.new('One').subscribe(test_list(test_sub('fdksjh')))
        Application.new('Two').subscribe(test_list(test_sub('fdklhf')))
        Application.new('Three').subscribe(test_list(test_sub('fkld')))

        expect(Application.all.collect(&:app_key)).to match_array(%w[one two three])

        Application.new('two').unsubscribe
        expect(Application.all.collect(&:app_key)).to match_array(%w[one three])
      end
    end

    describe '.new' do
      it 'should have a key' do
        expect(Application.new('something').app_key).to eq('something')

        expect(Application.new('some thing').app_key).to eq('some_thing')
        expect(Application.new('some-thing').app_key).to eq('some_thing')
        expect(Application.new('some_thing').app_key).to eq('some_thing')
        expect(Application.new('Some Thing').app_key).to eq('some_thing')
      end

      it 'should raise an error if not valid' do
        expect do
          Application.new('')
        end.to raise_error(RuntimeError, 'Invalid application name')

        expect do
          Application.new(nil)
        end.to raise_error(RuntimeError, 'Invalid application name')

        expect do
          Application.new('/')
        end.to raise_error(RuntimeError, 'Invalid application name')
      end
    end

    describe '#read_redis_hash' do
      it 'should handle old and new values' do
        QueueBus.redis { |redis| redis.hset('bus_app:myapp', 'new_one', QueueBus::Util.encode('queue_name' => 'x', 'bus_event_type' => 'event_name')) }
        QueueBus.redis { |redis| redis.hset('bus_app:myapp', 'old_one', 'oldqueue_name') }
        app = Application.new('myapp')
        val = app.send(:read_redis_hash)
        expect(val).to eq('new_one' => { 'queue_name' => 'x', 'bus_event_type' => 'event_name' }, 'old_one' => 'oldqueue_name')
      end
    end

    describe '#subscribe' do
      let(:sub1) { test_sub('event_one', 'default') }
      let(:sub2) { test_sub('event_two', 'default') }
      let(:sub3) { test_sub('event_three', 'other') }
      it 'should add array to redis' do
        expect(QueueBus.redis { |redis| redis.get('bus_app:myapp') }).to be_nil
        Application.new('myapp').subscribe(test_list(sub1, sub2))

        expect(QueueBus.redis { |redis| redis.hgetall('bus_app:myapp') }).to eq('event_two' => '{"queue_name":"default","key":"event_two","class":"::QueueBus::Rider","matcher":{"bus_event_type":"event_two"}}',
                                                                                'event_one' => '{"queue_name":"default","key":"event_one","class":"::QueueBus::Rider","matcher":{"bus_event_type":"event_one"}}')
        expect(QueueBus.redis { |redis| redis.hkeys('bus_app:myapp') }).to match_array(%w[event_one event_two])
        expect(QueueBus.redis { |redis| redis.smembers('bus_apps') }).to match_array(['myapp'])
      end
      it 'should add string to redis' do
        expect(QueueBus.redis { |redis| redis.get('bus_app:myapp') }).to be_nil
        Application.new('myapp').subscribe(test_list(sub1))

        expect(QueueBus.redis { |redis| redis.hgetall('bus_app:myapp') }).to eq('event_one' => '{"queue_name":"default","key":"event_one","class":"::QueueBus::Rider","matcher":{"bus_event_type":"event_one"}}')
        expect(QueueBus.redis { |redis| redis.hkeys('bus_app:myapp') }).to match_array(['event_one'])
        expect(QueueBus.redis { |redis| redis.smembers('bus_apps') }).to match_array(['myapp'])
      end
      it 'should multiple queues to redis' do
        expect(QueueBus.redis { |redis| redis.get('bus_app:myapp') }).to be_nil
        Application.new('myapp').subscribe(test_list(sub1, sub2, sub3))
        expect(QueueBus.redis { |redis| redis.hgetall('bus_app:myapp') }).to eq('event_two' => '{"queue_name":"default","key":"event_two","class":"::QueueBus::Rider","matcher":{"bus_event_type":"event_two"}}', 'event_one' => '{"queue_name":"default","key":"event_one","class":"::QueueBus::Rider","matcher":{"bus_event_type":"event_one"}}',
                                                                                'event_three' => '{"queue_name":"other","key":"event_three","class":"::QueueBus::Rider","matcher":{"bus_event_type":"event_three"}}')
        expect(QueueBus.redis { |redis| redis.hkeys('bus_app:myapp') }).to match_array(%w[event_three event_two event_one])
        expect(QueueBus.redis { |redis| redis.smembers('bus_apps') }).to match_array(['myapp'])
      end

      it 'should do nothing if nil or empty' do
        expect(QueueBus.redis { |redis| redis.get('bus_app:myapp') }).to be_nil

        Application.new('myapp').subscribe(nil)
        expect(QueueBus.redis { |redis| redis.get('bus_app:myapp') }).to be_nil

        Application.new('myapp').subscribe([])
        expect(QueueBus.redis { |redis| redis.get('bus_app:myapp') }).to be_nil
      end

      it 'should call unsubscribe' do
        app = Application.new('myapp')
        expect(app).to receive(:unsubscribe)
        app.subscribe([])
      end
    end

    describe '#unsubscribe' do
      it 'should remove items' do
        QueueBus.redis { |redis| redis.sadd('bus_apps', 'myapp') }
        QueueBus.redis { |redis| redis.sadd('bus_apps', 'other') }
        QueueBus.redis { |redis| redis.hset('bus_app:myapp', 'event_one', 'myapp_default') }

        Application.new('myapp').unsubscribe

        expect(QueueBus.redis { |redis| redis.smembers('bus_apps') }).to eq(['other'])
        expect(QueueBus.redis { |redis| redis.get('bus_app:myapp') }).to be_nil
      end
    end

    describe '#subscription_matches' do
      it 'should return if it is there' do
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'three').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to eq([])

        subs = test_list(test_sub('one_x'), test_sub('one_y'), test_sub('one'), test_sub('two'))
        Application.new('myapp').subscribe(subs)
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'three').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to eq([])

        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'two').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', 'two', 'default', '::QueueBus::Rider']])
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'one').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', 'one', 'default', '::QueueBus::Rider']])
      end

      it 'should handle * wildcards' do
        subs = test_list(test_sub('one.+'), test_sub('one'), test_sub('one_.*'), test_sub('two'))
        Application.new('myapp').subscribe(subs)
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'three').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to eq([])

        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'onex').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', 'one.+', 'default', '::QueueBus::Rider']])
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'one').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', 'one', 'default', '::QueueBus::Rider']])
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'one_x').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', 'one.+', 'default', '::QueueBus::Rider'], ['myapp', 'one_.*', 'default', '::QueueBus::Rider']])
      end

      it 'should handle actual regular expressions' do
        subs = test_list(test_sub(/one.+/), test_sub('one'), test_sub(/one_.*/), test_sub('two'))
        Application.new('myapp').subscribe(subs)
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'three').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to eq([])

        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'onex').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', '(?-mix:one.+)', 'default', '::QueueBus::Rider']])
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'donex').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', '(?-mix:one.+)', 'default', '::QueueBus::Rider']])
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'one').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', 'one', 'default', '::QueueBus::Rider']])
        expect(Application.new('myapp').subscription_matches('bus_event_type' => 'one_x').collect { |s| [s.app_key, s.key, s.queue_name, s.class_name] }).to match_array([['myapp', '(?-mix:one.+)', 'default', '::QueueBus::Rider'], ['myapp', '(?-mix:one_.*)', 'default', '::QueueBus::Rider']])
      end
    end
  end
end
