# frozen_string_literal: true

require 'socket'
require 'logger'

module QueueBus
  # This class contains all the configuration for a running queue bus application.
  class Config
    attr_accessor :default_queue, :hostname, :incoming_queue, :logger

    attr_reader :worker_middleware_stack
    attr_writer :local_mode

    def initialize
      @worker_middleware_stack = QueueBus::Middleware::Stack.new
      @incoming_queue = 'bus_incoming'
      @hostname = Socket.gethostname
    end

    # A wrapper that is always "truthy" but can contain an inner value. This is useful for
    # checking that a thread local variable is set to a value, even if that value happens to
    # be nil. This is important because setting a thread local value to nil will cause it to
    # be deleted.
    Wrap = Struct.new(:value)

    # Returns the current local mode of QueueBus
    def local_mode
      if Thread.current.thread_variable?(:queue_bus_local_mode)
        Thread.current.thread_variable_get(:queue_bus_local_mode).value
      else
        @local_mode
      end
    end

    # Overrides the current local mode for the duration of a block. This is a threadsafe
    # implementation. After, the global setting will be resumed.
    #
    # @param mode [Symbol] the mode to switch to
    def with_local_mode(mode)
      previous = Thread.current.thread_variable_get(:queue_bus_local_mode)
      Thread.current.thread_variable_set(:queue_bus_local_mode, Wrap.new(mode))
      yield if block_given?
    ensure
      Thread.current.thread_variable_set(:queue_bus_local_mode, previous)
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
      logger&.debug(message)
    end
  end
end
