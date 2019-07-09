require 'spec_helper'

describe "Publishing an event" do

  before(:each) do
    Timecop.freeze
    allow(QueueBus).to receive(:generate_uuid).and_return("idfhlkj")
  end
  after(:each) do
    Timecop.return
  end
  let(:bus_attrs) { {"bus_class_proxy"=>"QueueBus::Driver",
                     "bus_published_at" => Time.now.to_i,
                     "bus_id"=>"#{Time.now.to_i}-idfhlkj",
                     "bus_app_hostname" =>  `hostname 2>&1`.strip.sub(/.local/,'')} }

  it "should add it to Redis" do
    hash = {:one => 1, "two" => "here", "id" => 12 }
    event_name = "event_name"

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    expect(val).to eq(nil)

    QueueBus.publish(event_name, hash)

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    hash = JSON.parse(val)
    expect(hash["class"]).to eq("QueueBus::Worker")
    expect(hash["args"].size).to eq(1)
    expect(JSON.parse(hash["args"].first)).to eq({"bus_event_type" => event_name, "two"=>"here", "one"=>1, "id" => 12}.merge(bus_attrs))

  end

  it "should use the id if given" do
    hash = {:one => 1, "two" => "here", "bus_id" => "app-given" }
    event_name = "event_name"

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    expect(val).to eq(nil)

    QueueBus.publish(event_name, hash)

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    hash = JSON.parse(val)
    expect(hash["class"]).to eq("QueueBus::Worker")
    expect(hash["args"].size).to eq(1)
    expect(JSON.parse(hash["args"].first)).to eq({"bus_event_type" => event_name, "two"=>"here", "one"=>1}.merge(bus_attrs).merge("bus_id" => 'app-given'))
  end

  it "should add metadata via callback" do
    myval = 0
    QueueBus.before_publish = lambda { |att|
      att["mine"] = 4
      myval += 1
    }

    hash = {:one => 1, "two" => "here", "bus_id" => "app-given" }
    event_name = "event_name"

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    expect(val).to eq(nil)

    QueueBus.publish(event_name, hash)


    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    hash = JSON.parse(val)
    att = JSON.parse(hash["args"].first)
    expect(att["mine"]).to eq(4)
    expect(myval).to eq(1)
  end

  it "should set the timezone and locale if available" do
    expect(defined?(I18n)).to be_nil
    expect(Time.respond_to?(:zone)).to eq(false)

    stub_const("I18n", Class.new)
    allow(I18n).to receive(:locale).and_return("jp")

    allow(Time).to receive(:zone).and_return(double('zone', :name => "EST"))

    hash = {:one => 1, "two" => "here", "bus_id" => "app-given" }
    event_name = "event_name"

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    expect(val).to eq(nil)

    QueueBus.publish(event_name, hash)

    val = QueueBus.redis { |redis| redis.lpop("queue:bus_incoming") }
    hash = JSON.parse(val)
    expect(hash["class"]).to eq("QueueBus::Worker")
    att = JSON.parse(hash["args"].first)
    expect(att["bus_locale"]).to eq("jp")
    expect(att["bus_timezone"]).to eq("EST")
  end

end
