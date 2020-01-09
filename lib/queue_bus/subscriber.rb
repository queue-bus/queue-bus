# frozen_string_literal: true

module QueueBus
  # A mixin to configure subscriptions on a particular class
  module Subscriber
    def self.included(base)
      base.extend ClassMethods
    end

    # The class methods that will be added to the class it's included in. Use them to
    # configure and subscribe.
    module ClassMethods
      def application(app_key)
        @app_key = ::QueueBus::Application.normalize(app_key)
      end

      def app_key
        return @app_key if @app_key

        @app_key = ::QueueBus.default_app_key
        return @app_key if @app_key

        # module or class_name
        val = name.to_s.split('::').first
        @app_key = ::QueueBus::Util.underscore(val)
      end

      def subscribe(method_name, matcher_hash = nil)
        queue_name   = nil
        queue_name ||= instance_variable_get(:@queue) || (respond_to?(:queue) && queue)
        queue_name ||= ::QueueBus.default_queue
        queue_name ||= "#{app_key}_default"
        subscribe_queue(queue_name, method_name, matcher_hash)
      end

      def subscribe_queue(queue_name, method_name, matcher_hash = nil)
        klass = self
        matcher_hash ||= { 'bus_event_type' => method_name }
        sub_key = "#{name}.#{method_name}"
        dispatcher = ::QueueBus.dispatcher_by_key(app_key)
        dispatcher.add_subscription(queue_name, sub_key, klass.name.to_s, matcher_hash,
                                    ->(att) { klass.perform(att) })
      end

      def transform(method_name)
        @transform = method_name
      end

      def perform(attributes)
        ::QueueBus.with_global_attributes(attributes) do
          sub_key = attributes['bus_rider_sub_key']
          meth_key = sub_key.split('.').last
          queue_bus_execute(meth_key, attributes)
        end
      end

      def queue_bus_execute(key, attributes)
        args = attributes
        args = send(@transform, attributes) if @transform
        args = [args] unless args.is_a?(Array)
        me = if respond_to?(:subscriber_with_attributes)
               subscriber_with_attributes(attributes)
             else
               new
             end
        me.send(key, *args)
      end
    end
  end
end
