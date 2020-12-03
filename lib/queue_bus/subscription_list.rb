# frozen_string_literal: true

module QueueBus
  # Manages a set of subscriptions.
  #
  # The subscriptions are stored in redis but not by this class. Instead this class uses two
  # functions `to_redis` and `from_redis` to facilitate serialization without accessing redis
  # directly.
  #
  # To create a new SubscriptionList, use the static function `from_redis` and pass
  # it a hash that came from redis.
  #
  # To get a value fro redis, take your loaded SubscriptionList and call `to_redis` on it. The
  # returned value can be used to store in redis.
  class SubscriptionList
    class << self
      def from_redis(redis_hash)
        out = SubscriptionList.new

        redis_hash.each do |_key, value|
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
      if @subscriptions.key?(sub.key)
        raise "Duplicate key: #{sub.key} already exists " \
              "in the #{sub.queue_name} queue!"
      end
      @subscriptions[sub.key] = sub
    end

    def remove(sub)
      raise "Key #{sub.key} doesn't exist in the #{sub.queue_name} queue!" unless @subscriptions.key?(sub.key)

      @subscriptions.delete(sub.key)
    end

    def size
      @subscriptions.size
    end

    def empty?
      size.zero?
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
