# frozen_string_literal: true

# Creates a DSL for apps to define their blocks to run for event_types

module QueueBus
  # A Dispatch object can be used to declare an application along with it's various subscriptions.
  class Dispatch
    attr_reader :app_key, :subscriptions

    def initialize(app_key)
      @app_key = Application.normalize(app_key)
      @subscriptions = SubscriptionList.new
    end

    def size
      @subscriptions.size
    end

    def on_heartbeat(key, minute: nil, hour: nil, wday: nil, minute_interval: nil, hour_interval: nil, &block) # rubocop:disable Metrics/PerceivedComplexity, Metrics/MethodLength, Metrics/ParameterLists, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/LineLength
      if minute_interval && !minute_interval.positive?
        raise ArgumentError, 'minute_interval must be a positive integer'
      end

      if hour_interval && !hour_interval.positive?
        raise ArgumentError, 'hour_interval must be a positive integer'
      end

      matcher = { bus_event_type: :heartbeat_minutes }

      if minute
        raise ArgumentError, 'minute must not be negative' if minute.negative?

        matcher['minute'] = minute
      end

      if hour
        raise ArgumentError, 'hour must not be negative' if hour.negative?

        matcher['hour'] = hour
      end

      if wday
        raise ArgumentError, 'wday must not be negative' if wday.negative?

        matcher['wday'] = wday
      end

      subscribe(key, matcher) do |event|
        if (minute_interval.nil? || (event['minute'] % minute_interval).zero?) &&
           (hour_interval.nil? || (event['hour'] % hour_interval).zero?)

          # Yield the block passed in.
          block.call(event)
        end
      end
    end

    def subscribe(key, matcher_hash = nil, &block)
      dispatch_event('default', key, matcher_hash, block)
    end

    # allows definitions of other queues
    def method_missing(method_name, *args, &block)
      if args.size == 1 && block
        dispatch_event(method_name, args[0], nil, block)
      elsif args.size == 2 && block
        dispatch_event(method_name, args[0], args[1], block)
      else
        super
      end
    end

    def execute(key, attributes)
      sub = subscriptions.key(key)
      if sub
        sub.execute!(attributes)
      else
        # TODO: log that it's not there
      end
    end

    def subscription_matches(attributes)
      out = subscriptions.matches(attributes)
      out.each do |sub|
        sub.app_key = app_key
      end
      out
    end

    def dispatch_event(queue, key, matcher_hash, block)
      # if not matcher_hash, assume key is a event_type regex
      matcher_hash ||= { 'bus_event_type' => key }
      add_subscription("#{app_key}_#{queue}", key, '::QueueBus::Rider', matcher_hash, block)
    end

    def add_subscription(queue_name, key, class_name, matcher_hash = nil, block)
      sub = Subscription.register(queue_name, key, class_name, matcher_hash, block)
      subscriptions.add(sub)
      sub
    end
  end
end
