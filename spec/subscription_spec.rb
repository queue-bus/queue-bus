require 'spec_helper'

module QueueBus
  describe Subscription do
    it "should normalize the queue name" do
      expect(Subscription.new("test",  "my_event", "MyClass", {}, nil).queue_name).to eq("test")
      expect(Subscription.new("tes t", "my_event", "MyClass", {}, nil).queue_name).to eq("tes_t")
      expect(Subscription.new("t%s",   "my_event", "MyClass", {}, nil).queue_name).to eq("t_s")
    end
    
    describe ".register" do
      it "should take in args from dispatcher" do
        executor = Proc.new { |attributes| }
        sub = Subscription.register("queue_name", "mykey", "MyClass", {"bus_event_type" => "my_event"}, executor)
        expect(sub.send(:executor)).to eq(executor)
        expect(sub.matcher.filters).to eq({"bus_event_type" => "my_event"})
        expect(sub.queue_name).to eq("queue_name")
        expect(sub.key).to eq("mykey")
        expect(sub.class_name).to eq("MyClass")
      end
    end
    
    describe "#execute!" do
      it "should call the executor with the attributes" do
        exec = Object.new
        expect(exec).to receive(:call)
        
        sub = Subscription.new("x", "y", "ClassName", {}, exec)
        sub.execute!({"ok" => true})
      end
    end
    
    describe "#to_redis" do
      it "should return what to store for this subscription" do
        sub = Subscription.new("queue_one", "xyz", "ClassName", {"bus_event_type" => "my_event"}, nil)
        expect(sub.to_redis).to eq({"queue_name" => "queue_one", "key" => "xyz", "class" => "ClassName", "matcher" => {"bus_event_type" => "my_event"}})
      end
    end
    
    describe "#matches?" do
      it "should do pattern stuff" do
        expect(Subscription.new("x", "id", "ClassName", {"bus_event_type" => "one"}).matches?("bus_event_type" => "one")).to eq(true)
        expect(Subscription.new("x", "id", "ClassName", {"bus_event_type" => "one"}).matches?("bus_event_type" => "onex")).to eq(false)
        expect(Subscription.new("x", "id", "ClassName", {"bus_event_type" => "^one.*$"}).matches?("bus_event_type" => "onex")).to eq(true)
        expect(Subscription.new("x", "id", "ClassName", {"bus_event_type" => "one.*"}).matches?("bus_event_type" => "onex")).to eq(true)
        expect(Subscription.new("x", "id", "ClassName", {"bus_event_type" => "one.?"}).matches?("bus_event_type" => "onex")).to eq(true)
        expect(Subscription.new("x", "id", "ClassName", {"bus_event_type" => "one.?"}).matches?("bus_event_type" => "one")).to eq(true)
        expect(Subscription.new("x", "id", "ClassName", {"bus_event_type" => "\\"}).matches?("bus_event_type" => "one")).to eq(false)
      end
    end
    
  end
end