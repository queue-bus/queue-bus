# frozen_string_literal: true

module QueueBus
  # A simple publishing worker for QueueBus. Makes publishing asynchronously possible since
  # it may be enqueued to the background worker with a delay. This will allow the event to
  # be published at a later time.
  class Publisher
    class << self
      def perform(attributes)
        event_type = attributes['bus_event_type']
        ::QueueBus.log_worker("Publisher running: #{event_type} - #{attributes.inspect}")
        ::QueueBus.publish(event_type, attributes)
      end
    end
  end
end
