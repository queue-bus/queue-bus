# frozen_string_literal: true

require 'spec_helper'

RSpec.describe QueueBus::Middleware do
  subject { described_class::Stack.new }

  let(:args) { { rand: rand } }
  let(:inner) { proc {} }

  let(:base_class) do
    # Creates a unique base class that provides tracking of calls.
    Class.new(QueueBus::Middleware::Abstract) do
      class << self
        attr_accessor :called_at
      end

      def call(_args)
        self.class.called_at = Time.now
        @app.call
      end
    end
  end

  context 'with none configured' do
    it 'falls through' do
      expect(inner).to receive(:call)
      subject.run(args, &inner)
    end
  end

  context 'with the abstract class configured' do
    before do
      subject.use(QueueBus::Middleware::Abstract)
    end

    it 'runs the inner' do
      expect(inner).to receive(:call).and_call_original
      subject.run(args, &inner)
    end
  end

  context 'with one middleware' do
    let(:middleware) do
      Class.new(base_class) do
        class << self
          attr_accessor :args
        end

        def call(args)
          self.class.args = args
          super
        end
      end
    end

    before do
      subject.use(middleware)
    end

    it 'calls the middleware with the args' do
      subject.run(args, &inner)

      expect(middleware.args).to eql args
    end

    it 'calls the middleware and then inner' do
      expect(inner).to receive(:call).and_call_original
      subject.run(args, &inner)
      expect(middleware.called_at).not_to be_nil
    end

    context 'and the middleware does not yield' do
      let(:middleware) do
        Class.new(base_class) do
          def call(_args)
            self.class.called_at = Time.now
            # no-op
          end
        end
      end

      it 'does not run inner' do
        expect(inner).not_to receive(:call).and_call_original
        subject.run(args, &inner)
        expect(middleware.called_at).not_to be_nil
      end
    end
  end

  context 'with more than one middleware' do
    let(:middlewares) do
      Array.new(rand(2..20)).map do
        Class.new(base_class)
      end
    end

    before do
      middlewares.each do |middleware|
        subject.use(middleware)
      end
    end

    it 'calls all the middlewares in order' do
      expect(inner).to receive(:call).and_call_original
      subject.run(args, &inner)
      # Test by sorting by when it was called. This should be in a strict
      # order based on call order.
      expect(middlewares.sort_by(&:called_at)).to eq middlewares
    end
  end
end
