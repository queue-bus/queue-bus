require 'spec_helper'

module QueueBus
  describe Matcher do
    it "should already return false on empty filters" do
      matcher = Matcher.new({})
      expect(matcher.matches?({})).to  eq(false)
      expect(matcher.matches?(nil)).to  eq(false)
      expect(matcher.matches?("name" => "val")).to eq(false)
    end

    it "should not crash if nil inputs" do
      matcher = Matcher.new("name" => "val")
      expect(matcher.matches?(nil)).to eq(false)
    end

    it "string filter to/from redis" do
      matcher = Matcher.new("name" => "val")
      expect(matcher.matches?("name" => "val")).to   eq(true)
      expect(matcher.matches?("name" => " val")).to  eq(false)
      expect(matcher.matches?("name" => "zval")).to  eq(false)
    end

    it "regex filter" do
      matcher = Matcher.new("name" => /^[cb]a+t/)
      expect(matcher.matches?("name" => "cat")).to eq(true)
      expect(matcher.matches?("name" => "bat")).to eq(true)
      expect(matcher.matches?("name" => "caaaaat")).to eq(true)
      expect(matcher.matches?("name" => "ct")).to eq(false)
      expect(matcher.matches?("name" => "bcat")).to eq(false)
    end

    it "present filter" do
      matcher = Matcher.new("name" => :present)
      expect(matcher.matches?("name" => "")).to eq(false)
      expect(matcher.matches?("name" => "cat")).to eq(true)
      expect(matcher.matches?("name" => "bear")).to eq(true)
      expect(matcher.matches?("other" => "bear")).to eq(false)
    end

    it "blank filter" do
      matcher = Matcher.new("name" => :blank)
      expect(matcher.matches?("name" => nil)).to eq(true)
      expect(matcher.matches?("other" => "bear")).to eq(true)
      expect(matcher.matches?("name" => "")).to eq(true)
      expect(matcher.matches?("name" => "  ")).to eq(true)
      expect(matcher.matches?("name" => "bear")).to eq(false)
      expect(matcher.matches?("name" => "   s ")).to eq(false)
    end

    it "nil filter" do
      matcher = Matcher.new("name" => :nil)
      expect(matcher.matches?("name" => nil)).to eq(true)
      expect(matcher.matches?("other" => "bear")).to eq(true)
      expect(matcher.matches?("name" => "")).to eq(false)
      expect(matcher.matches?("name" => "  ")).to eq(false)
      expect(matcher.matches?("name" => "bear")).to eq(false)
    end

    it "key filter" do
      matcher = Matcher.new("name" => :key)
      expect(matcher.matches?("name" => nil)).to eq(true)
      expect(matcher.matches?("other" => "bear")).to eq(false)
      expect(matcher.matches?("name" => "")).to eq(true)
      expect(matcher.matches?("name" => "  ")).to eq(true)
      expect(matcher.matches?("name" => "bear")).to eq(true)
    end

    it "empty filter" do
      matcher = Matcher.new("name" => :empty)
      expect(matcher.matches?("name" => nil)).to eq(false)
      expect(matcher.matches?("other" => "bear")).to eq(false)
      expect(matcher.matches?("name" => "")).to eq(true)
      expect(matcher.matches?("name" => "  ")).to eq(false)
      expect(matcher.matches?("name" => "bear")).to eq(false)
      expect(matcher.matches?("name" => "   s ")).to eq(false)
    end

    it "value filter" do
      matcher = Matcher.new("name" => :value)
      expect(matcher.matches?("name" => nil)).to eq(false)
      expect(matcher.matches?("other" => "bear")).to eq(false)
      expect(matcher.matches?("name" => "")).to eq(true)
      expect(matcher.matches?("name" => "  ")).to eq(true)
      expect(matcher.matches?("name" => "bear")).to eq(true)
      expect(matcher.matches?("name" => "   s ")).to eq(true)
    end

    it "multiple filters" do
      matcher = Matcher.new("name" => /^[cb]a+t/, "state" => "sleeping")
      expect(matcher.matches?("state" => "sleeping", "name" => "cat")).to  eq(true)
      expect(matcher.matches?("state" => "awake", "name" => "cat")).to     eq(false)
      expect(matcher.matches?("state" => "sleeping", "name" => "bat")).to  eq(true)
      expect(matcher.matches?("state" => "sleeping", "name" => "bear")).to eq(false)
      expect(matcher.matches?("state" => "awake", "name" => "bear")).to    eq(false)
    end

    it "regex should go back and forth into redis" do
      matcher = Matcher.new("name" => /^[cb]a+t/)
      expect(matcher.matches?("name" => "cat")).to eq(true)
      expect(matcher.matches?("name" => "bat")).to eq(true)
      expect(matcher.matches?("name" => "caaaaat")).to eq(true)
      expect(matcher.matches?("name" => "ct")).to eq(false)
      expect(matcher.matches?("name" => "bcat")).to eq(false)

      QueueBus.redis { |redis| redis.set("temp1", QueueBus::Util.encode(matcher.to_redis) ) }
      redis = QueueBus.redis { |redis| redis.get("temp1") }
      matcher = Matcher.new(QueueBus::Util.decode(redis))
      expect(matcher.matches?("name" => "cat")).to eq(true)
      expect(matcher.matches?("name" => "bat")).to eq(true)
      expect(matcher.matches?("name" => "caaaaat")).to eq(true)
      expect(matcher.matches?("name" => "ct")).to eq(false)
      expect(matcher.matches?("name" => "bcat")).to eq(false)

      QueueBus.redis { |redis| redis.set("temp2", QueueBus::Util.encode(matcher.to_redis) ) }
      redis = QueueBus.redis { |redis| redis.get("temp2") }
      matcher = Matcher.new(QueueBus::Util.decode(redis))
      expect(matcher.matches?("name" => "cat")).to eq(true)
      expect(matcher.matches?("name" => "bat")).to eq(true)
      expect(matcher.matches?("name" => "caaaaat")).to eq(true)
      expect(matcher.matches?("name" => "ct")).to eq(false)
      expect(matcher.matches?("name" => "bcat")).to eq(false)
    end

    it "special value should go back and forth into redis" do
      matcher = Matcher.new("name" => :blank)
      expect(matcher.matches?("name" => "cat")).to eq(false)
      expect(matcher.matches?("name" => "")).to    eq(true)

      QueueBus.redis { |redis| redis.set("temp1", QueueBus::Util.encode(matcher.to_redis) ) }
      redis= QueueBus.redis { |redis| redis.get("temp1") }
      matcher = Matcher.new(QueueBus::Util.decode(redis))
      expect(matcher.matches?("name" => "cat")).to eq(false)
      expect(matcher.matches?("name" => "")).to    eq(true)

      QueueBus.redis { |redis| redis.set("temp2", QueueBus::Util.encode(matcher.to_redis) ) }
      redis= QueueBus.redis { |redis| redis.get("temp2") }
      matcher = Matcher.new(QueueBus::Util.decode(redis))
      expect(matcher.matches?("name" => "cat")).to eq(false)
      expect(matcher.matches?("name" => "")).to    eq(true)
    end
  end
end
