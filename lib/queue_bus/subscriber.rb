module QueueBus
  module Subscriber

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods

      def application(app_key)
        @app_key = ::QueueBus::Application.normalize(app_key)
      end

      def app_key
        return @app_key if @app_key
        @app_key = ::QueueBus.default_app_key
        return @app_key if @app_key
        # module or class_name
        val = self.name.to_s.split("::").first
        @app_key = ::QueueBus::Util.underscore(val)
      end

      def subscribe(method_name, matcher_hash = nil)
        queue_name   = nil
        queue_name ||= self.instance_variable_get(:@queue) || (self.respond_to?(:queue) && self.queue)
        queue_name ||= ::QueueBus.default_queue
        queue_name ||= "#{app_key}_default"
        subscribe_queue(queue_name, method_name, matcher_hash)
      end

      def subscribe_queue(queue_name, method_name, matcher_hash = nil)
        klass = self
        matcher_hash ||= {"bus_event_type" => method_name}
        sub_key = "#{self.name}.#{method_name}"
        dispatcher = ::QueueBus.dispatcher_by_key(app_key)
        dispatcher.add_subscription(queue_name, sub_key, klass.name.to_s, matcher_hash, lambda{ |att| klass.perform(att) })
      end

      def transform(method_name)
        @transform = method_name
      end

      def perform(attributes)
        ::QueueBus.with_global_attributes(attributes) do
          sub_key = attributes["bus_rider_sub_key"]
          meth_key = sub_key.split(".").last
          queue_bus_execute(meth_key, attributes)
        end
      end

      def queue_bus_execute(key, attributes)
        args = attributes
        args = send(@transform, attributes) if @transform
        args = [args] unless args.is_a?(Array)
        if self.respond_to?(:subscriber_with_attributes)
          me = self.subscriber_with_attributes(attributes)
        else
          me = self.new
        end
        me.send(key, *args)
      end
    end
  end
end
