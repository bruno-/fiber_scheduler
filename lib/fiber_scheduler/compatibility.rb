class FiberScheduler
  module Compatibility
    Close = Class.new(RuntimeError)

    def fiber(*args, **opts, &block)
      return super unless Compatibility.internal?

      # This is `Fiber.schedule` call inside `FiberScheduler { ... }` block.
      type = args.first
      case type
      when :blocking
        Fiber.new(blocking: true) {
          Compatibility.set_internal!
          yield
        }.tap(&:resume)

      when :waiting
        parent = Fiber.current
        finished = false # prevents races
        blocking = false # prevents #unblock-ing a fiber that never blocked

        # Don't pass *args and **opts to an unknown fiber scheduler class.
        fiber = super() do
          Compatibility.set_internal!
          yield
        ensure
          finished = true
          unblock(nil, parent) if blocking
        end

        unless finished
          blocking = true
          block(nil, nil)
        end

        fiber

      when :volatile
        # Transfer to current fiber some time after a volatile fiber yields.
        unblock(nil, Fiber.current)
        # Alternative to #unblock: Fiber.scheduler.push(Fiber.current)

        fiber = Fiber.new(blocking: false) do
          Compatibility.set_internal!
          yield
        rescue Close
          # Fiber scheduler is closing.
        ensure
          _volatile.delete(Fiber.current)
        end
        _volatile[fiber] = nil
        fiber.tap(&:transfer)

      when nil
        # Don't pass *args and **opts to an unknown fiber scheduler class.
        super() do
          Compatibility.set_internal!
          yield
        end

      else
        raise "Unknown type"
      end
    end

    # #close and #_volatile handle a complexity in Async::Scheduler#close, more
    # specifically this line:
    # https://github.com/socketry/async/blob/456df488d801572821eaf5ec2fda10e3b9744a5f/lib/async/scheduler.rb#L55
    def close
      super
    rescue
      if _volatile.empty?
        Kernel.raise
      else
        # #dup is used because #_volatile is modified during iteration.
        _volatile.dup.each do |fiber, _|
          fiber.raise(Close)
        end

        super # retry
      end
    end

    def _volatile
      @_volatile ||= {}
    end

    def self.set_internal!
      Thread.current[:_fiber_scheduler] = true # Sets a FIBER local var!
    end

    def self.internal?
      Thread.current[:_fiber_scheduler]
    end
  end
end
