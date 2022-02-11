class FiberScheduler
  class Trigger
    include Comparable

    attr_reader :time

    def initialize(duration, fiber, action, *args)
      @time = Process.clock_gettime(Process::CLOCK_MONOTONIC) + duration
      @fiber = fiber
      @action = action
      @args = args

      @disabled = nil
    end

    def <=>(other)
      raise unless other.is_a?(self.class)

      @time <=> other.time
    end

    def call
      return unless @fiber.alive?

      @fiber.public_send(@action, *@args)
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
