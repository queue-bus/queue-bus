require 'spec_helper'

describe "adapter is set" do
  it "should call it's enabled! method on init" do
    QueueBus.send(:reset)
    expect_any_instance_of(adapter_under_test_class).to receive(:enabled!)
    instance = adapter_under_test_class.new
    QueueBus.send(:reset)
  end

  it "should be defaulting to Data from spec_helper" do
    expect(QueueBus.adapter.is_a?(adapter_under_test_class)).to eq(true)
  end
end
