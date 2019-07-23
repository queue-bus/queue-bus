# frozen_string_literal: true

require 'socket'

module QueueBus
  # This class contains all the configuration for a running queue bus application.
  class Config
    attr_accessor :default_queue, :local_mode, :hostname, :incoming_queue, :logger

    attr_reader :worker_middleware_stack

    def initialize
      @worker_middleware_stack = QueueBus::Middleware::Stack.new
      @incoming_queue = 'bus_incoming'
      @hostname = Socket.gethostname
    end

    def adapter=(val)
      raise "Adapter already set to #{@adapter_instance.class.name}" if has_adapter?

      @adapter_instance =
        if val.is_a?(Class)
          val.new
        elsif val.is_a?(::QueueBus::Adapters::Base)
          val
        else
          class_name = ::QueueBus::Util.classify(val)
          ::QueueBus::Util.constantize("::QueueBus::Adapters::#{class_name}").new
        end
    end

    def adapter
      return @adapter_instance if has_adapter?

      raise 'no adapter has been set'
    end

    # Checks whether an adapter is set and returns true if it is.
    def has_adapter? # rubocop:disable Naming/PredicateName
      !@adapter_instance.nil?
    end

    def redis(&block)
      # TODO: could allow setting for non-redis adapters
      adapter.redis(&block)
    end

    attr_reader :default_app_key
    def default_app_key=(val)
      @default_app_key = Application.normalize(val)
    end

    def before_publish=(callback)
      @before_publish_callback = callback
    end

    def before_publish_callback(attributes)
      @before_publish_callback&.call(attributes)
    end

    def log_application(message)
      logger&.info(message)
    end

    def log_worker(message)
      logger&.debug(message) if ENV['LOGGING'] || ENV['VERBOSE'] || ENV['VVERBOSE']
    end
  end
end
