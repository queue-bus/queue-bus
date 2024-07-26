# frozen_string_literal: true

module QueueBus
  # A helper class for executing Rake tasks.
  class TaskManager
    attr_reader :logging

    def initialize(logging)
      @logging = logging
    end

    def subscribe!
      count = 0
      ::QueueBus.dispatchers.each do |dispatcher|
        subscriptions = dispatcher.subscriptions
        next if subscriptions.empty?

        count += subscriptions.size
        log "Subscribing #{dispatcher.app_key} to #{subscriptions.size} subscriptions"
        app = ::QueueBus::Application.new(dispatcher.app_key)
        app.subscribe(subscriptions, logging)
        log '  ...done'
      end
      count
    end

    def unsubscribe_queue!(app_key, queue)
      log "Unsubcribing #{queue} from #{app_key}"
      app = ::QueueBus::Application.new(app_key)
      app.unsubscribe_queue(queue)
      log "  ...done"
    end

    def unsubscribe_app!(app_key)
      log "Removing all subscriptions for #{app_key}"
      app = ::QueueBus::Application.new(app_key)
      app.unsubscribe
      log "  ...done"
    end

    def unsubscribe!
      count = 0
      ::QueueBus.dispatchers.each do |dispatcher|
        log "Unsubcribing from #{dispatcher.app_key}"
        app = ::QueueBus::Application.new(dispatcher.app_key)
        app.unsubscribe
        count += 1
        log '  ...done'
      end
    end

    def queue_names
      # let's not talk to redis in here. Seems to screw things up
      queues = []
      ::QueueBus.dispatchers.each do |dispatcher|
        dispatcher.subscriptions.all.each do |sub|
          queues << sub.queue_name
        end
      end

      queues.uniq
    end

    def log(message)
      puts(message) if logging
    end
  end
end
