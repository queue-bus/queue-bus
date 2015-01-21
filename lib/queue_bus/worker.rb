module QueueBus
  class Worker

    def self.perform(json)
      klass = nil
      attributes = ::QueueBus::Util.decode(json)
      begin
        class_name = attributes["bus_class_proxy"]
        klass = ::QueueBus::Util.constantize(class_name)
      rescue NameError
        # not there anymore
        return
      end

      klass.perform(attributes)
    end

    # all our workers include this one
    def perform(json)
      # instance method level support for sidekiq
      self.class.perform(json)
    end
  end
end
