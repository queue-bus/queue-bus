# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe QueueBus::Worker do
  it 'proxies to given class' do
    hash = { 'bus_class_proxy' => 'QueueBus::Driver', 'ok' => true }
    expect(QueueBus::Driver).to receive(:perform).with(hash)
    QueueBus::Worker.perform(JSON.generate(hash))
  end

  it 'uses an instance' do
    hash = { 'bus_class_proxy' => 'QueueBus::Rider', 'ok' => true }
    expect(QueueBus::Rider).to receive(:perform).with(hash)
    QueueBus::Worker.new.perform(JSON.generate(hash))
  end

  it 'does not freak out if class not there anymore' do
    hash = { 'bus_class_proxy' => 'QueueBus::BadClass', 'ok' => true }
    expect do
      QueueBus::Worker.perform(JSON.generate(hash))
    end.not_to raise_error
  end

  it 'raises error if proxy raises error' do
    hash = { 'bus_class_proxy' => 'QueueBus::Rider', 'ok' => true }
    expect(QueueBus::Rider).to receive(:perform).with(hash).and_raise('rider crash')
    expect do
      QueueBus::Worker.perform(JSON.generate(hash))
    end.to raise_error(RuntimeError, 'rider crash')
  end

  it 'runs the middleware stack' do
    hash = { 'bus_class_proxy' => 'QueueBus::Driver', 'ok' => true }
    expect(QueueBus.worker_middleware_stack).to receive(:run).with(hash).and_yield
    QueueBus::Worker.perform(JSON.generate(hash))
  end
end
