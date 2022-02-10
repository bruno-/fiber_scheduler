require_relative "timer"

class FiberScheduler
  class Timers
    def initialize
      # Array is sorted by Timer#time
      @timers = []
    end

    def call
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      while @timers.any? && @timers.first.time <= now
        timer = @timers.shift
        unless timer.disabled?
          timer.call
        end
      end
    end

    def add(duration, &block)
      timer = Timer.new(duration, &block)

      if @timers.empty?
        @timers << timer
        return timer
      end

      # binary search
      min = 0
      max = @timers.size - 1
      while min <= max
        index = (min + max) / 2
        t = @timers[index]

        if t > timer
          if index.zero? || @timers[index - 1] <= timer
            # found it
            break
          else
            # @timers[index - 1] > timer
            max = index - 1
          end
        else
          # t <= timer
          index += 1
          min = index
        end
      end

      @timers.insert(index, timer)
      timer
    end

    def interval
      # Prune disabled timers
      while @timers.first&.disabled?
        @timers.shift
      end

      return if @timers.empty?

      interval = @timers.first.interval

      interval >= 0 ? interval : 0
    end

    def inspect
      @timers.inspect
    end
  end
end
