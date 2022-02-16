class FiberScheduler
  module Compatibility
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
        super() do
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

      when :fleeting
        # Transfer to current fiber some time after a fleeting fiber yields.
        unblock(nil, Fiber.current)
        # Alternative to #unblock: Fiber.scheduler.push(Fiber.current)

        Fiber.new(blocking: false) {
          Compatibility.set_internal!
          yield
        }.transfer

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

    def self.set_internal!
      Thread.current[:_fiber_scheduler] = true # Sets a FIBER local var!
    end

    def self.internal?
      Thread.current[:_fiber_scheduler]
    end
  end
end
