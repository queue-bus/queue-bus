module QueueBus
  # publishes on a delay
  class Publisher

    class << self
      def perform(attributes)
        event_type = attributes["bus_event_type"]
        ::QueueBus.log_worker("Publisher running: #{event_type} - #{attributes.inspect}")
        ::QueueBus.publish(event_type, attributes)
      end
    end

  end
end