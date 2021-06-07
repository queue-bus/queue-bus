# frozen_string_literal: true

require 'spec_helper'

describe 'Publishing an event in the future' do
  before(:each) do
    Timecop.freeze(now)
    allow(QueueBus).to receive(:generate_uuid).and_return('idfhlkj')
  end
  after(:each) do
    Timecop.return
  end
  let(:delayed_attrs) do
    {
      'bus_delayed_until' => future.to_i,
      'bus_id' => "#{now.to_i}-idfhlkj",
      'bus_app_hostname' => `hostname 2>&1`.strip.sub(/.local/, '')
    }
  end

  let(:bus_attrs) { delayed_attrs.merge('bus_published_at' => worktime.to_i) }
  let(:now)    { Time.parse('01/01/2013 5:00') }
  let(:future) { Time.at(now.to_i + 60) }
  let(:worktime) { Time.at(future.to_i + 1) }

  it 'should add it to Redis then to the real queue' do
    hash = { :one => 1, 'two' => 'here', 'id' => 12 }
    event_name = 'event_name'
    QueueBus.publish_at(future, event_name, hash)

    schedule = QueueBus.redis { |redis| redis.zrange('delayed_queue_schedule', 0, 1) }
    expect(schedule).to eq([future.to_i.to_s])

    val = QueueBus.redis { |redis| redis.lpop("delayed:#{future.to_i}") }
    hash = JSON.parse(val)

    expect(hash['class']).to eq('QueueBus::Worker')
    expect(hash['args'].size).to eq(1)
    expect(JSON.parse(hash['args'].first)).to eq({ 'bus_class_proxy' => 'QueueBus::Publisher', 'bus_event_type' => 'event_name', "bus_context" => nil, 'two' => 'here', 'one' => 1, 'id' => 12 }.merge(delayed_attrs))
    expect(hash['queue']).to eq('bus_incoming')

    val = QueueBus.redis { |redis| redis.lpop('queue:bus_incoming') }
    expect(val).to eq(nil) # nothing really added

    Timecop.freeze(worktime)
    QueueBus::Publisher.perform(JSON.parse(hash['args'].first))

    val = QueueBus.redis { |redis| redis.lpop('queue:bus_incoming') }
    hash = JSON.parse(val)
    expect(hash['class']).to eq('QueueBus::Worker')
    expect(hash['args'].size).to eq(1)
    expect(JSON.parse(hash['args'].first)).to eq({ 'bus_class_proxy' => 'QueueBus::Driver', 'bus_event_type' => 'event_name', "bus_context" => nil, 'two' => 'here', 'one' => 1, 'id' => 12 }.merge(bus_attrs))
  end
end
