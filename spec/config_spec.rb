require 'spec_helper'

module QueueBus
  module Adapters
    class TestOne

    end
  end
end

describe "QueueBus config" do
  it "should set the default app key" do
    expect(QueueBus.default_app_key).to eq(nil)

    QueueBus.default_app_key = "my_app"
    expect(QueueBus.default_app_key).to eq("my_app")

    QueueBus.default_app_key = "something here"
    expect(QueueBus.default_app_key).to eq("something_here")
  end

  it "should set the default queue" do
    expect(QueueBus.default_queue).to eq(nil)

    QueueBus.default_queue = "my_queue"
    expect(QueueBus.default_queue).to eq("my_queue")
  end

  it "should set the local mode" do
    expect(QueueBus.local_mode).to eq(nil)
    QueueBus.local_mode = :standalone
    expect(QueueBus.local_mode).to eq(:standalone)
  end

  it "should set the hostname" do
    expect(QueueBus.hostname).not_to eq(nil)
    QueueBus.hostname = "whatever"
    expect(QueueBus.hostname).to eq("whatever")
  end

  it "should set before_publish callback" do
    QueueBus.before_publish = lambda {|attributes| 42 }
    expect(QueueBus.before_publish_callback({})).to eq(42)
  end


  it "should use the default Redis connection" do
    expect(QueueBus.redis { |redis| redis }).not_to eq(nil)
  end

  it "should default to given adapter" do
    expect(QueueBus.adapter.is_a?(adapter_under_test_class)).to eq(true)

    # and should raise if already set
    expect {
      QueueBus.adapter = :data
    }.to raise_error(RuntimeError, "Adapter already set to QueueBus::Adapters::Data")
  end

  context "with a fresh load" do
    before(:each) do
      QueueBus.send(:reset)
    end

    it "should be able to be set to resque" do
      QueueBus.adapter = adapter_under_test_symbol
      expect(QueueBus.adapter.is_a?(adapter_under_test_class)).to eq(true)

      # and should raise if already set
      expect {
        QueueBus.adapter = :data
      }.to raise_error(RuntimeError, "Adapter already set to QueueBus::Adapters::Data")
    end

    it "should be able to be set to something else" do

      QueueBus.adapter = :test_one
      expect(QueueBus.adapter.is_a?(QueueBus::Adapters::TestOne)).to eq(true)
    end
  end


end
