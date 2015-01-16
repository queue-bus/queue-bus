require 'spec_helper'

module QueueBus
  describe Adapters::Data do
    it "should call it's enabled! method on init" do
      QueueBus.send(:reset)
      QueueBus::Adapters::Data.any_instance.should_receive(:enabled!)
      instance = QueueBus::Adapters::Data.new
      QueueBus.adapter = instance # prevents making a new one and causing and error in :after
    end

    it "should be defaulting to Data from spec_helper" do
      QueueBus.adapter.is_a?(QueueBus::Adapters::Data).should == true
    end
  end
end
