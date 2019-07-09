require 'spec_helper'

module QueueBus
  describe Driver do
    before(:each) do
      Application.new("app1").subscribe(test_list(test_sub("event1"), test_sub("event2"), test_sub("event3")))
      Application.new("app2").subscribe(test_list(test_sub("event2","other"), test_sub("event4", "more")))
      Application.new("app3").subscribe(test_list(test_sub("event[45]"), test_sub("event5"), test_sub("event6")))
      Timecop.freeze
    end
    after(:each) do
      Timecop.return
    end

    let(:bus_attrs) { {"bus_driven_at" => Time.now.to_i, "bus_rider_class_name"=>"::QueueBus::Rider", "bus_class_proxy" => "::QueueBus::Rider"} }

    describe ".subscription_matches" do
      it "return empty array when none" do
        expect(Driver.subscription_matches("bus_event_type" => "else").collect{|s| [s.app_key, s.key, s.queue_name, s.class_name]}).to eq([])
        expect(Driver.subscription_matches("bus_event_type" => "event").collect{|s| [s.app_key, s.key, s.queue_name, s.class_name]}).to eq([])
      end
      it "should return a match" do
        expect(Driver.subscription_matches("bus_event_type" => "event1").collect{|s| [s.app_key, s.key, s.queue_name, s.class_name]}).to match_array([["app1", "event1", "default", "::QueueBus::Rider"]])
        expect(Driver.subscription_matches("bus_event_type" => "event6").collect{|s| [s.app_key, s.key, s.queue_name, s.class_name]}).to match_array([["app3", "event6", "default", "::QueueBus::Rider"]])
      end
      it "should match multiple apps" do
        expect(Driver.subscription_matches("bus_event_type" => "event2").collect{|s| [s.app_key, s.key, s.queue_name, s.class_name]}).to match_array([["app1", "event2", "default", "::QueueBus::Rider"], ["app2", "event2", "other", "::QueueBus::Rider"]])
      end
      it "should match multiple apps with patterns" do
        expect(Driver.subscription_matches("bus_event_type" => "event4").collect{|s| [s.app_key, s.key, s.queue_name, s.class_name]}).to match_array([["app3", "event[45]", "default", "::QueueBus::Rider"], ["app2", "event4", "more", "::QueueBus::Rider"]])
      end
      it "should match multiple events in same app" do
        expect(Driver.subscription_matches("bus_event_type" => "event5").collect{|s| [s.app_key, s.key, s.queue_name, s.class_name]}).to match_array([["app3", "event[45]", "default", "::QueueBus::Rider"], ["app3", "event5", "default", "::QueueBus::Rider"]])
      end
    end

    describe ".perform" do
      let(:attributes) { {"x" => "y", "bus_class_proxy" => "ResqueBus::Driver"} }

      before(:each) do
        expect(QueueBus.redis { |redis| redis.smembers("queues") }).to eq([])
        expect(QueueBus.redis { |redis| redis.lpop("queue:app1_default") }).to be_nil
        expect(QueueBus.redis { |redis| redis.lpop("queue:app2_default") }).to be_nil
        expect(QueueBus.redis { |redis| redis.lpop("queue:app3_default") }).to be_nil
      end

      it "should do nothing when empty" do
        Driver.perform(attributes.merge("bus_event_type" => "else"))
        expect(QueueBus.redis { |redis| redis.smembers("queues") }).to eq([])
      end

      it "should queue up the riders in redis" do
        expect(QueueBus.redis { |redis| redis.lpop("queue:app1_default") }).to be_nil
        Driver.perform(attributes.merge("bus_event_type" => "event1"))
        expect(QueueBus.redis { |redis| redis.smembers("queues") }).to match_array(["default"])

        hash = JSON.parse(QueueBus.redis { |redis| redis.lpop("queue:default") })
        expect(hash["class"]).to eq("QueueBus::Worker")
        expect(hash["args"].size).to eq(1)
        expect(JSON.parse(hash["args"].first)).to eq({"bus_rider_app_key"=>"app1", "x" => "y", "bus_event_type" => "event1", "bus_rider_sub_key"=>"event1", "bus_rider_queue" => "default"}.merge(bus_attrs))
      end

      it "should queue up to multiple" do
        Driver.perform(attributes.merge("bus_event_type" => "event4"))
        expect(QueueBus.redis { |redis| redis.smembers("queues") }).to match_array(["default", "more"])

        hash = JSON.parse(QueueBus.redis { |redis| redis.lpop("queue:more") })
        expect(hash["class"]).to eq("QueueBus::Worker")
        expect(hash["args"].size).to eq(1)
        expect(JSON.parse(hash["args"].first)).to eq({"bus_rider_app_key"=>"app2", "x" => "y", "bus_event_type" => "event4", "bus_rider_sub_key"=>"event4", "bus_rider_queue" => "more"}.merge(bus_attrs))

        hash = JSON.parse(QueueBus.redis { |redis| redis.lpop("queue:default") })
        expect(hash["class"]).to eq("QueueBus::Worker")
        expect(hash["args"].size).to eq(1)
        expect(JSON.parse(hash["args"].first)).to eq({"bus_rider_app_key"=>"app3", "x" => "y", "bus_event_type" => "event4", "bus_rider_sub_key"=>"event[45]", "bus_rider_queue" => "default"}.merge(bus_attrs))
      end

      it "should queue up to the same" do
        Driver.perform(attributes.merge("bus_event_type" => "event5"))
        expect(QueueBus.redis { |redis| redis.smembers("queues") }).to match_array(["default"])

        expect(QueueBus.redis { |redis| redis.llen("queue:default") }).to eq(2)

        pop1 = JSON.parse(QueueBus.redis { |redis| redis.lpop("queue:default") })
        pop2 = JSON.parse(QueueBus.redis { |redis| redis.lpop("queue:default") })

        pargs1 = JSON.parse(pop1["args"].first)
        pargs2 = JSON.parse(pop2["args"].first)
        if pargs1["bus_rider_sub_key"] == "event5"
          hash1 = pop1
          hash2 = pop2
          args1 = pargs1
          args2 = pargs2
        else
          hash1 = pop2
          hash2 = pop1
          args1 = pargs2
          args2 = pargs1
        end

        expect(hash1["class"]).to eq("QueueBus::Worker")
        expect(args1).to eq({"bus_rider_app_key"=>"app3", "x" => "y", "bus_event_type" => "event5", "bus_rider_sub_key"=>"event5", "bus_rider_queue" => "default"}.merge(bus_attrs))

        expect(hash2["class"]).to eq("QueueBus::Worker")
        expect(args2).to eq({"bus_rider_app_key"=>"app3", "x" => "y", "bus_event_type" => "event5", "bus_rider_sub_key"=>"event[45]", "bus_rider_queue" => "default"}.merge(bus_attrs))
      end
    end
  end
end
