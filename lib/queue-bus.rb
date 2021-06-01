# frozen_string_literal: true

require 'queue_bus/version'
require 'forwardable'

# The main QueueBus module. Most operations you will need to execute should be executed
# on this top level domain.
module QueueBus
  autoload :Application,      'queue_bus/application'
  autoload :Config,           'queue_bus/config'
  autoload :Dispatch,         'queue_bus/dispatch'
  autoload :Dispatchers,      'queue_bus/dispatchers'
  autoload :Driver,           'queue_bus/driver'
  autoload :Heartbeat,        'queue_bus/heartbeat'
  autoload :Local,            'queue_bus/local'
  autoload :Matcher,          'queue_bus/matcher'
  autoload :Middleware,       'queue_bus/middleware'
  autoload :Publishing,       'queue_bus/publishing'
  autoload :Publisher,        'queue_bus/publisher'
  autoload :Rider,            'queue_bus/rider'
  autoload :Subscriber,       'queue_bus/subscriber'
  autoload :Subscription,     'queue_bus/subscription'
  autoload :SubscriptionList, 'queue_bus/subscription_list'
  autoload :TaskManager,      'queue_bus/task_manager'
  autoload :Util,             'queue_bus/util'
  autoload :Worker,           'queue_bus/worker'

  # A module for all adapters, current and future.
  module Adapters
    autoload :Base,           'queue_bus/adapters/base'
    autoload :Data,           'queue_bus/adapters/data'
  end

  class << self
    include Publishing
    extend Forwardable

    def_delegators :config, :default_app_key=, :default_app_key,
                   :default_queue=, :default_queue,
                   :local_mode=, :local_mode, :with_local_mode,
                   :before_publish=, :before_publish_callback,
                   :logger=, :logger, :log_application, :log_worker,
                   :hostname=, :hostname,
                   :adapter=, :adapter, :has_adapter?,
                   :incoming_queue=, :incoming_queue,
                   :redis, :worker_middleware_stack,
                   :context=, :context, :in_context

    def_delegators :_dispatchers, :dispatch, :dispatchers, :dispatcher_by_key, :dispatcher_execute

    protected

    def reset
      # used by tests
      @config = nil
      @_dispatchers = nil
    end

    def config
      @config ||= ::QueueBus::Config.new
    end

    def _dispatchers
      @_dispatchers ||= ::QueueBus::Dispatchers.new
    end
  end
end
