# frozen_string_literal: true

module QueueBus
  # A collection of Dispatches
  #
  # Each Dispatch is an application with it's own set of subscriptions. This is a master object
  # that provides some basic controls over the set of applications.
  class Dispatchers
    # Fetches a dispatch for the application key and binds the provided block to it.
    def dispatch(app_key = nil, &block)
      dispatcher = dispatcher_by_key(app_key)
      dispatcher.instance_eval(&block)
      dispatcher
    end

    def dispatchers
      @dispatchers ||= {}
      @dispatchers.values
    end

    def dispatcher_by_key(app_key)
      app_key = Application.normalize(app_key || ::QueueBus.default_app_key)
      @dispatchers ||= {}
      @dispatchers[app_key] ||= Dispatch.new(app_key)
    end

    def dispatcher_execute(app_key, key, attributes)
      @dispatchers ||= {}
      dispatcher = @dispatchers[app_key]
      dispatcher&.execute(key, attributes)
    end
  end
end
