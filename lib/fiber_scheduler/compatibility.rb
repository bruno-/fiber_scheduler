class FiberScheduler
  module Compatibility
    def fiber(*args, **opts, &block)
      return super unless Compatibility.internal?

      # This is `Fiber.schedule` call inside `FiberScheduler { ... }` block.
      if opts[:blocking]
        Fiber.new(blocking: true) {
          Compatibility.set_internal!
          yield
        }.tap(&:resume)

      elsif opts[:waiting]
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

      elsif opts[:fleeting]
        # Transfer to current fiber some time - after a fleeting fiber yields.
        unblock(nil, Fiber.current)
        # Alternative to #unblock: Fiber.scheduler.push(Fiber.current)

        Fiber.new(blocking: false) {
          Compatibility.set_internal!
          yield
        }.transfer

      else
        # Don't pass *args and **opts to an unknown fiber scheduler class.
        super() do
          Compatibility.set_internal!
          yield
        end
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
