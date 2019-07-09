require 'spec_helper'

module QueueBus
  describe Rider do
    it "should call execute" do
      expect(QueueBus).to receive(:dispatcher_execute)
      Rider.perform("bus_rider_app_key" => "app", "bus_rider_sub_key" => "sub", "ok" => true, "bus_event_type" => "event_name")
    end

    it "should change the value" do
      QueueBus.dispatch("r1") do
        subscribe "event_name" do |attributes|
          Runner1.run(attributes)
        end
      end
      expect(Runner1.value).to eq(0)
      Rider.perform("bus_locale" => "en", "bus_timezone" => "PST", "bus_rider_app_key" => "r1", "bus_rider_sub_key" => "event_name", "ok" => true, "bus_event_type" => "event_name")
      Rider.perform("bus_rider_app_key" => "other", "bus_rider_sub_key" => "event_name", "ok" => true, "bus_event_type" => "event_name")
      expect(Runner1.value).to eq(1)
    end

    it "should set the timezone and locale if present" do
      QueueBus.dispatch("r1") do
        subscribe "event_name" do |attributes|
          Runner1.run(attributes)
        end
      end

      expect(defined?(I18n)).to be_nil
      expect(Time.respond_to?(:zone)).to eq(false)

      stub_const("I18n", Class.new)
      expect(I18n).to receive(:locale=).with("en")
      expect(Time).to receive(:zone=).with("PST")

      Rider.perform("bus_locale" => "en", "bus_timezone" => "PST", "bus_rider_app_key" => "r1", "bus_rider_sub_key" => "event_name", "ok" => true, "bus_event_type" => "event_name")
    end
  end
end
