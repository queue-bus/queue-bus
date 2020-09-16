# frozen_string_literal: true

module QueueBus
  # When run, will calculate all of the heartbeats that need to be sent and then broadcasts
  # those events out for execution. By always backfilling it ensures that no heartbeat is
  # ever missed.
  class Heartbeat
    class << self
      def lock_key
        'bus:heartbeat:lock'
      end

      def lock_seconds
        60
      end

      def lock!
        now = Time.now.to_i
        timeout = now + lock_seconds + 2

        ::QueueBus.redis do |redis|
          # return true if we successfully acquired the lock
          return timeout if redis.setnx(lock_key, timeout)

          # see if the existing timeout is still valid and return false if it is
          # (we cannot acquire the lock during the timeout period)
          return 0 if now <= redis.get(lock_key).to_i

          # otherwise set the timeout and ensure that no other worker has
          # acquired the lock
          if now > redis.getset(lock_key, timeout).to_i
            return timeout
          else
            return 0
          end
        end
      end

      def unlock!
        ::QueueBus.redis { |redis| redis.del(lock_key) }
      end

      def redis_key
        'bus:heartbeat:timestamp'
      end

      def environment_name
        ENV['RAILS_ENV'] || ENV['RACK_ENV'] || ENV['BUS_ENV']
      end

      def get_saved_minute!
        key = ::QueueBus.redis { |redis| redis.get(redis_key) }
        return nil if key.nil?

        case environment_name
        when 'development', 'test'
          # only 3 minutes in development; otherwise, TONS of events if not run in a while
          three_ago = Time.now.to_i / 60 - 3
          key = three_ago if key.to_i < three_ago
        end
        key.to_i
      end

      def set_saved_minute!(epoch_minute)
        ::QueueBus.redis { |redis| redis.set(redis_key, epoch_minute) }
      end

      def perform(*_args)
        real_now = Time.now.to_i
        run_until = lock! - 2
        return if run_until < real_now

        while (real_now = Time.now.to_i) < run_until
          minutes = real_now.to_i / 60
          last = get_saved_minute!
          if last
            break if minutes <= last

            minutes = last + 1
          end

          seconds = minutes * 60
          hours   = minutes / 60
          days    = minutes / (60 * 24)

          now = Time.at(seconds)

          attributes = {}
          attributes['epoch_seconds'] = seconds
          attributes['epoch_minutes'] = minutes
          attributes['epoch_hours']   = hours
          attributes['epoch_days']    = days

          attributes['minute'] = now.min
          attributes['hour']   = now.hour
          attributes['day']    = now.day
          attributes['month']  = now.month
          attributes['year']   = now.year
          attributes['yday']   = now.yday
          attributes['wday']   = now.wday

          ::QueueBus.publish('heartbeat_minutes', attributes)
          set_saved_minute!(minutes)
        end

        unlock!
      end
    end
  end
end
