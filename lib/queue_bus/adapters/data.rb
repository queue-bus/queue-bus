# a base adapter just for publishing and redis connection
module QueueBus
  module Adapters
    class Data < QueueBus::Adapters::Base
      def enabled!
        # nothing to do
      end

      def redis=(client)
        @redis = client
      end

      def redis(&block)
        raise "no redis instance set" unless @redis
        block.call(@redis)
      end

      def enqueue(queue_name, klass, hash)
        push(queue_name, :class => klass.to_s, :args => [hash])
      end

      def enqueue_at(epoch_seconds, queue_name, klass, hash)
        item = delayed_job_to_hash_with_queue(queue_name, klass, [hash])
        delayed_push(epoch_seconds, item)
      end

      def setup_heartbeat!(queue_name)
        raise NotImplementedError
      end

      protected

      def default_namespace
        :resque
      end

      def push(queue, item)
        watch_queue(queue)
        self.redis { |redis| redis.rpush "queue:#{queue}", ::QueueBus::Util.encode(item) }
      end

      # Used internally to keep track of which queues we've created.
      # Don't call this directly.
      def watch_queue(queue)
        self.redis { |redis| redis.sadd(:queues, queue.to_s) }
      end

      ### From Resque Scheduler
      # Used internally to stuff the item into the schedule sorted list.
      # +timestamp+ can be either in seconds or a datetime object
      # Insertion if O(log(n)).
      # Returns true if it's the first job to be scheduled at that time, else false
      def delayed_push(timestamp, item)
        self.redis do |redis|
          # First add this item to the list for this timestamp
          redis.rpush("delayed:#{timestamp.to_i}", ::QueueBus::Util.encode(item))

          # Now, add this timestamp to the zsets.  The score and the value are
          # the same since we'll be querying by timestamp, and we don't have
          # anything else to store.
          redis.zadd :delayed_queue_schedule, timestamp.to_i, timestamp.to_i
        end
      end
      
      def delayed_job_to_hash_with_queue(queue, klass, args)
        {:class => klass.to_s, :args => args, :queue => queue}
      end
    end
  end
end
