# require 'queue_bus/tasks'
# will give you these tasks

namespace :queuebus do

  desc "Subscribes this application to QueueBus events"
  task :subscribe => [ :preload ] do
    manager = ::QueueBus::TaskManager.new(true)
    count = manager.subscribe!
    raise "No subscriptions created" if count == 0
  end

  desc "Unsubscribes this application from QueueBus events"
  task :unsubscribe => [ :preload ] do
    manager = ::QueueBus::TaskManager.new(true)
    count = manager.unsubscribe!
    puts "No subscriptions unsubscribed" if count == 0
  end

  desc "List QueueBus queues that need worked"
  task :queues => [ :preload ] do
    manager = ResqueBus::TaskManager.new(false)
    queues = manager.queue_names + ['bus_incoming']
    puts queues.join(", ")
  end

  # Preload app files if this is Rails
  # you can also do this to load the right things
  task :preload do
    require 'queue-bus'
  end
end
