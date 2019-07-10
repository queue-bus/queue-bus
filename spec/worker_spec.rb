require 'spec_helper'

module QueueBus
  describe Worker do
    it "should proxy to given class" do
      hash = {"bus_class_proxy" => "QueueBus::Driver", "ok" => true}
      expect(QueueBus::Driver).to receive(:perform).with(hash)
      QueueBus::Worker.perform(JSON.generate(hash))
    end

    it "should use instance" do
      hash = {"bus_class_proxy" => "QueueBus::Rider", "ok" => true}
      expect(QueueBus::Rider).to receive(:perform).with(hash)
      QueueBus::Worker.new.perform(JSON.generate(hash))
    end

    it "should not freak out if class not there anymore" do
      hash = {"bus_class_proxy" => "QueueBus::BadClass", "ok" => true}
      expect {
        QueueBus::Worker.perform(JSON.generate(hash))
      }.not_to raise_error
    end

    it "should raise error if proxy raises error" do
      hash = {"bus_class_proxy" => "QueueBus::Rider", "ok" => true}
      expect(QueueBus::Rider).to receive(:perform).with(hash).and_raise("rider crash")
      expect {
        QueueBus::Worker.perform(JSON.generate(hash))
      }.to raise_error(RuntimeError, 'rider crash')
    end
  end
end
