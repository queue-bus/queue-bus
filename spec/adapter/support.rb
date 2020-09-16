# frozen_string_literal: true

require 'redis'

def reset_test_adapter
  QueueBus.send(:reset)
  QueueBus.adapter = :data
  QueueBus.adapter.redis = if ENV['REDIS_URL']
                             Redis.new(url: ENV['REDIS_URL'])
                           else
                             Redis.new
                           end
end

def adapter_under_test_class
  QueueBus::Adapters::Data
end

def adapter_under_test_symbol
  :data
end
