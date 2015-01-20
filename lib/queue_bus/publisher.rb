module QueueBus
  # publishes on a delay
  class Publisher

    class << self
      def perform(*args)
        # TODO: move this to just resquebus for fallback
        if args.size > 1
          # handles older arguments
          event_type = args.first
          attributes = args.last
        else
          attributes = args.first
          event_type = attributes["bus_event_type"]
        end
        ::QueueBus.log_worker("Publisher running: #{event_type} - #{attributes.inspect}")
        ::QueueBus.publish(event_type, attributes)
      end
    end

  end
end