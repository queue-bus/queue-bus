# frozen_string_literal: true

module QueueBus
  # An Application is the top level unifier for a number of subscriptions. It allows for
  # the toggling of an entire applications subscriptions.
  class Application
    class << self
      def all
        # note the names arent the same as we started with
        ::QueueBus.redis do |redis|
          app_keys = redis.smembers(app_list_key)
          apps = app_keys.collect { |val| new(val) }

          hashes = redis.pipelined do |p|
            apps.each do |app|
              p.hgetall(app.redis_key)
            end
          end

          apps.zip(hashes).each do |app, hash|
            app._hydrate_redis_hash(hash)
          end

          apps
        end
      end
    end

    attr_reader :app_key, :redis_key

    def initialize(app_key)
      @app_key = self.class.normalize(app_key)
      @redis_key = "#{self.class.app_single_key}:#{@app_key}"
      # raise error if only other chars
      raise 'Invalid application name' if @app_key.gsub('_', '').empty?
    end

    def subscribe(subscription_list, log = false)
      @subscriptions = nil

      if subscription_list.nil? || subscription_list.empty?
        unsubscribe
        return true
      end

      temp_key = "temp_#{redis_key}:#{rand(999_999_999)}"

      ::QueueBus.redis do |redis|
        redis_hash = subscription_list.to_redis

        redis_hash.each do |key, hash|
          redis.hset(temp_key, key, QueueBus::Util.encode(hash))
        end

        # make it the real one
        redis.rename(temp_key, redis_key)
        redis.sadd?(self.class.app_list_key, app_key)

        redis.hgetall(redis_key).inspect if log
      end

      true
    end

    def unsubscribe_queue(queue)
      # Filters out all subscriptions that match the supplied queue name.
      ::QueueBus.redis do |redis|
        read_redis_hash.each do |key, hash_details|
          redis.hdel(redis_key, key) if queue == hash_details["queue_name"]
        end
      end
    end

    def unsubscribe
      # Remove everything.
      ::QueueBus.redis do |redis|
        redis.srem(self.class.app_list_key, app_key)
        redis.del(redis_key)
      end
    end

    def no_connect_queue_names_for(subscriptions)
      out = []
      subscriptions.all.each do |sub|
        queue = "#{app_key}_#{sub.queue_name}"
        out << queue
      end
      out << "#{app_key}_default"
      out.uniq
    end

    def subscription_matches(attributes)
      out = subscriptions.matches(attributes)
      out.each do |sub|
        sub.app_key = app_key
      end
      out
    end

    def event_display_tuples
      out = []
      subscriptions.all.each do |sub|
        out << [sub.class_name, sub.queue_name, sub.matcher.filters]
      end
      out
    end

    def _hydrate_redis_hash(hash)
      @raw_redis_hash = hash
    end

    protected

    def self.normalize(val)
      val.to_s.gsub(/\W/, '_').downcase
    end

    def self.app_list_key
      'bus_apps'
    end

    def self.app_single_key
      'bus_app'
    end

    def event_queues
      ::QueueBus.redis { |redis| redis.hgetall(redis_key) }
    end

    def subscriptions
      @subscriptions ||= SubscriptionList.from_redis(read_redis_hash)
    end

    def read_redis_hash
      out = {}
      raw_redis_hash.each do |key, val|
        begin
          out[key] = ::QueueBus::Util.decode(val)
        rescue ::QueueBus::Util::DecodeException
          out[key] = val
        end
      end
      out
    end

    private

    def raw_redis_hash
      return @raw_redis_hash if @raw_redis_hash

      ::QueueBus.redis do |redis|
        redis.hgetall(redis_key)
      end
    end
  end
end
