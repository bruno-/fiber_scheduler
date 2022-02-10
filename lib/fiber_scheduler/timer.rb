class FiberScheduler
  class Timer
    include Comparable

    attr_reader :time

    def initialize(duration, &block)
      @time = Process.clock_gettime(Process::CLOCK_MONOTONIC) + duration
      @block = block
    end

    def <=>(other)
      raise unless other.is_a?(self.class)

      @time <=> other.time
    end

    def call
      @block.call
    end

    def interval
      @time - Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def inspect
      "#<#{self.class} time=#{@time}>"
    end
  end
end
