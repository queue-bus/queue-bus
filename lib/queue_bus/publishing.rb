# frozen_string_literal: true

module QueueBus
  # The publishing mixin provides the main interactions that users will use
  # to interact with the queue bus. This module is not interacted with directly and instead
  # is included inte the `QueueBus` module.
  module Publishing
    def with_global_attributes(attributes)
      original_timezone = false
      original_locale   = false

      if attributes['bus_locale'] && defined?(I18n) && I18n.respond_to?(:locale=)
        original_locale = I18n.locale if I18n.respond_to?(:locale)
        I18n.locale = attributes['bus_locale']
      end

      if attributes['bus_timezone'] && defined?(Time) && Time.respond_to?(:zone=)
        original_timezone = Time.zone if Time.respond_to?(:zone)
        Time.zone = attributes['bus_timezone']
      end

      yield
    ensure
      I18n.locale = original_locale   unless original_locale   == false
      Time.zone   = original_timezone unless original_timezone == false
    end

    def publish_metadata(event_type, attributes = {})
      # TODO: "bus_app_key" => application.app_key ?
      bus_attr = { 'bus_published_at' => Time.now.to_i, 'bus_event_type' => event_type }
      bus_attr['bus_id']           = "#{Time.now.to_i}-#{generate_uuid}"
      bus_attr['bus_app_hostname'] = ::QueueBus.hostname
      bus_attr['bus_context'] = ::QueueBus.context
      if defined?(I18n) && I18n.respond_to?(:locale) && I18n.locale
        bus_attr['bus_locale']       = I18n.locale.to_s
      end
      if defined?(Time) && Time.respond_to?(:zone) && Time.zone
        bus_attr['bus_timezone']     = Time.zone.name
      end
      out = bus_attr.merge(attributes || {})
      ::QueueBus.before_publish_callback(out)
      out
    end

    def generate_uuid
      require 'securerandom' unless defined?(SecureRandom)
      SecureRandom.uuid
    rescue Exception => e
      # secure random not there
      # big random number a few times
      n_bytes = [42].pack('i').size
      n_bits = n_bytes * 8
      max = 2**(n_bits - 2) - 1
      "#{rand(max)}-#{rand(max)}-#{rand(max)}"
    end

    def publish(event_type, attributes = {})
      to_publish = publish_metadata(event_type, attributes)

      ::QueueBus.log_application("Event published: #{event_type} #{to_publish.inspect}")
      if local_mode
        ::QueueBus::Local.publish(to_publish) # TODO: use different adapters
      else
        enqueue_to(::QueueBus.incoming_queue, ::QueueBus::Driver, to_publish)
      end
    end

    def publish_at(timestamp_or_epoch, event_type, attributes = {})
      to_publish = publish_metadata(event_type, attributes)
      to_publish['bus_delayed_until'] ||= timestamp_or_epoch.to_i
      to_publish.delete('bus_published_at') unless attributes['bus_published_at'] # will be put on when it actually does it
      to_publish['bus_class_proxy'] = ::QueueBus::Publisher.name.to_s

      ::QueueBus.log_application("Event published:#{event_type} #{to_publish.inspect} publish_at: #{timestamp_or_epoch.to_i}")
      delayed_enqueue_to(timestamp_or_epoch.to_i, incoming_queue, ::QueueBus::Worker, to_publish)
    end

    def enqueue_to(queue_name, class_name, hash)
      class_name = class_name.name if class_name.is_a?(Class)
      hash = hash.merge('bus_class_proxy' => class_name.to_s)
      ::QueueBus.adapter.enqueue(queue_name, ::QueueBus::Worker, ::QueueBus::Util.encode(hash || {}))
    end

    def delayed_enqueue_to(epoch_seconds, queue_name, klass, hash)
      ::QueueBus.adapter.enqueue_at(epoch_seconds, queue_name, klass, ::QueueBus::Util.encode(hash || {}))
    end

    def heartbeat!
      ::QueueBus.adapter.setup_heartbeat!(incoming_queue)
    end
  end
end
