module QueueBus
  class Config
    def adapter=val
      raise "Adapter already set to #{@adapter_instance.class.name}" if @adapter_instance
      if val.is_a?(Class)
        @adapter_instance = name_or_klass.new
      elsif val.is_a?(::QueueBus::Adapters::Base)
        @adapter_instance = val
      else
        class_name = ::QueueBus::Util.classify(val)
        @adapter_instance = ::QueueBus::Util.constantize("::QueueBus::Adapters::#{class_name}").new
      end
      @adapter_instance
    end

    def adapter
      return @adapter_instance if @adapter_instance
      raise "no adapter has been set"
    end

    def redis(&block)
      # TODO: could allow setting for non-redis adapters
      adapter.redis(&block)
    end

    def default_app_key=val
      @default_app_key = Application.normalize(val)
    end

    def default_app_key
      @default_app_key
    end

    def default_queue=val
      @default_queue = val
    end

    def default_queue
      @default_queue
    end

    def local_mode=value
      @local_mode = value
    end

    def local_mode
      @local_mode
    end

    def incoming_queue=val
      @incoming_queue = val
    end

    def incoming_queue
      @incoming_queue ||= "bus_incoming"
    end

    def worker_middleware_stack
      @worker_middleware_stack ||= QueueBus::Middleware::Stack.new
    end

    def hostname
      @hostname ||= `hostname 2>&1`.strip.sub(/.local/,'')
    end

    def hostname=val
      @hostname = val
    end

    def before_publish=(proc)
      @before_publish_callback = proc
    end

    def before_publish_callback(attributes)
      if @before_publish_callback
        @before_publish_callback.call(attributes)
      end
    end

    def logger
      @logger
    end

    def logger=val
      @logger = val
    end

    def log_application(message)
      if logger
        time = Time.now.strftime('%H:%M:%S %Y-%m-%d')
        logger.info("** [#{time}] #$$: QueueBus #{message}")
      end
    end

    def log_worker(message)
      if ENV['LOGGING'] || ENV['VERBOSE'] || ENV['VVERBOSE']
        time = Time.now.strftime('%H:%M:%S %Y-%m-%d')
        puts "** [#{time}] #$$: #{message}"
      end
    end
  end
end
