class FiberScheduler
  Error = Class.new(RuntimeError)

  class Timeout
    include Comparable

    Error = Class.new(FiberScheduler::Error)

    attr_reader :time

    def initialize(duration, fiber, method, *args)
      @time = Process.clock_gettime(Process::CLOCK_MONOTONIC) + duration
      @fiber = fiber
      @method = method
      @args = args

      @disabled = nil
    end

    def <=>(other)
      raise unless other.is_a?(self.class)

      @time <=> other.time
    end

    def call
      return unless @fiber.alive?

      @fiber.public_send(@method, *@args)
    end

    def interval
      @time - Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def disable
      @disabled = true
    end

    def disabled?
      @disabled
    end

    def inspect
      "#<#{self.class} time=#{@time}>"
    end
  end
end
