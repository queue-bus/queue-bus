require 'redis'

def reset_test_adapter
  QueueBus.send(:reset)
  QueueBus.adapter = :data
  QueueBus.adapter.redis = Redis.new
end

def adapter_under_test_class
  QueueBus::Adapters::Data
end

def adapter_under_test_symbol
  :data
end
