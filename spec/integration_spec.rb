# frozen_string_literal: true

require 'spec_helper'

module QueueBus
  describe 'Integration' do
    it 'should round trip attributes' do
      write1 = Subscription.new('default', 'key1', 'MyClass1', 'bus_event_type' => 'event_one')
      write2 = Subscription.new('else_ok', 'key2', 'MyClass2', 'bus_event_type' => /^[ab]here/) # regex

      expect(write1.matches?('bus_event_type' => 'event_one')).to  eq(true)
      expect(write1.matches?('bus_event_type' => 'event_one1')).to eq(false)
      expect(write1.matches?('bus_event_type' => 'aevent_one')).to eq(false)

      expect(write2.matches?('bus_event_type' => 'ahere')).to eq(true)
      expect(write2.matches?('bus_event_type' => 'bhere')).to eq(true)
      expect(write2.matches?('bus_event_type' => 'qhere')).to eq(false)
      expect(write2.matches?('bus_event_type' => 'abhere')).to eq(false)
      expect(write2.matches?('bus_event_type' => '[ab]here')).to eq(false)

      write = SubscriptionList.new
      write.add(write1)
      write.add(write2)

      app = Application.new('test')
      app.subscribe(write)

      reset_test_adapter # reset to make sure we read from redis
      app = Application.new('test')
      read = app.send(:subscriptions)

      expect(read.size).to eq(2)
      read1 = read.key('key1')
      read2 = read.key('key2')
      expect(read1).not_to be_nil
      expect(read2).not_to be_nil

      expect(read1.queue_name).to eq('default')
      expect(read1.class_name).to eq('MyClass1')
      expect(read2.queue_name).to eq('else_ok')
      expect(read2.class_name).to eq('MyClass2')

      expect(read1.matches?('bus_event_type' => 'event_one')).to  eq(true)
      expect(read1.matches?('bus_event_type' => 'event_one1')).to eq(false)
      expect(read1.matches?('bus_event_type' => 'aevent_one')).to eq(false)

      expect(read2.matches?('bus_event_type' => 'ahere')).to eq(true)
      expect(read2.matches?('bus_event_type' => 'bhere')).to eq(true)
      expect(read2.matches?('bus_event_type' => 'qhere')).to eq(false)
      expect(read2.matches?('bus_event_type' => 'abhere')).to eq(false)
      expect(read2.matches?('bus_event_type' => '[ab]here')).to eq(false)
    end
  end
end
