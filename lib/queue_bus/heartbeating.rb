module QueueBus
  module Heartbeating
    def heartbeat!
      # MIGRATE TODO: have to be moved to adapter
      
      # turn on the heartbeat
      # should be down after loading scheduler yml if you do that
      # otherwise, anytime
      require 'resque/scheduler'
      name     = 'bus_hearbeat'
      schedule = { 'class' => '::QueueBus::Heartbeat',
                   'cron'  => '* * * * *',   # every minute
                   'queue' => incoming_queue,
                   'description' => 'I publish a heartbeat_minutes event every minute'
                 }
      if ::Resque::Scheduler.dynamic
        ::Resque.set_schedule(name, schedule)
      end
      ::Resque.schedule[name] = schedule
    end
  end
end
