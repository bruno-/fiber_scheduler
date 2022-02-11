require_relative "trigger"

class FiberScheduler
  class Triggers
    def initialize
      # Array is sorted by Trigger#time
      @triggers = []
    end

    def call
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      while @triggers.any? && @triggers.first.time <= now
        trigger = @triggers.shift
        unless trigger.disabled?
          trigger.call
        end
      end
    end

    def raise_in(duration, *args, **options)
      call_in(duration, :raise, *args, **options)
    end

    def transfer_in(duration, *args, **options)
      call_in(duration, :transfer, *args, **options)
    end

    def interval
      # Prune disabled triggers
      while @triggers.first&.disabled?
        @triggers.shift
      end

      return if @triggers.empty?

      interval = @triggers.first.interval

      interval >= 0 ? interval : 0
    end

    def inspect
      @triggers.inspect
    end

    private

    def call_in(duration, action, *args, fiber: Fiber.current)
      trigger = Trigger.new(duration, fiber, action, *args)

      if @triggers.empty?
        @triggers << trigger
        return trigger
      end

      # binary search
      min = 0
      max = @triggers.size - 1
      while min <= max
        index = (min + max) / 2
        t = @triggers[index]

        if t > trigger
          if index.zero? || @triggers[index - 1] <= trigger
            # found it
            break
          else
            # @triggers[index - 1] > trigger
            max = index - 1
          end
        else
          # t <= trigger
          index += 1
          min = index
        end
      end

      @triggers.insert(index, trigger)
      trigger
    end
  end
end
