# frozen_string_literal: true

module QueueBus
  module Middleware
    # A base class for implementing a middleware. Inheriting from this will
    # provide a constructor and a basic call method. Override the call method
    # to implement your own logic. Calling the instance variable `@app` will
    # drive the middleware stack.
    class Abstract
      def initialize(app)
        @app = app
      end

      def call(_args)
        @app.call
      end
    end

    # A stack of middleware. You can modify the stack using the provided
    # helper methods.
    class Stack
      def initialize
        @middlewares = []
      end

      def use(middleware)
        @middlewares << middleware
      end

      def run(args, &inner)
        Runner.new(args: args, stack: @middlewares.dup, inner: inner).call
      end
    end

    # Runs the middleware stack by passing it self to each class.
    class Runner
      def initialize(args:, stack:, inner:)
        @stack = stack
        @inner = inner
        @args = args
      end

      def call
        middleware = @stack.shift

        if middleware
          middleware.new(self).call(@args)
        else
          @inner.call
        end
      end
    end
  end
end
