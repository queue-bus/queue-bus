module QueueBus
  class SubscriptionList

    class << self
      def from_redis(redis_hash)
        out = SubscriptionList.new
        
        redis_hash.each do |key, value|
          sub = Subscription.from_redis(value)
          out.add(sub) if sub
        end

        out
      end
    end

    def to_redis
      out = {}
      @subscriptions.values.each do |sub|
        out[sub.key] = sub.to_redis
      end
      out
    end
    
    def initialize
      @subscriptions = {}
    end
    
    def add(sub)
      raise "Duplicate key: #{sub.key} already exists " \
            "in the #{sub.queue_name} queue!" if @subscriptions.key?(sub.key)
      @subscriptions[sub.key] = sub
    end
    
    def size
      @subscriptions.size
    end
    
    def key(key)
      @subscriptions[key.to_s]
    end
    
    def all
      @subscriptions.values
    end
    
    def matches(attributes)
      out = []
      all.each do |sub|
        out << sub if sub.matches?(attributes)
      end
      out
    end
  end
end