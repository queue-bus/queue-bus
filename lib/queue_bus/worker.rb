module QueueBus
  module Worker

    def self.included(base)
      ::QueueBus.adapter.worker_included(base)
    end

    # all our workers include this one
    def perform(*args)
      # instance method level support for sidekiq
      self.class.perform(*args)
    end
  end
end
