require "resolv"
require_relative "fiber_scheduler/compatibility"
require_relative "fiber_scheduler/selector"
require_relative "fiber_scheduler/timeouts"

begin
  # Use io/event selector if available
  require "io/event"
rescue LoadError
end

module Kernel
  def FiberScheduler(type = nil, &block)
    if Fiber.scheduler.nil?
      Fiber.set_scheduler(FiberScheduler.new)

      begin
        yield
      ensure
        Fiber.set_scheduler(nil)
      end

    else
      scheduler = Fiber.scheduler
      # Fiber.scheduler already set, just schedule a fiber.
      if scheduler.is_a?(FiberScheduler)
        # The default waiting is 'true' as that is the most intuitive behavior
        # for a nested FiberScheduler call.
        Fiber.schedule(type, &block)

        # Unknown fiber scheduler class; can't just pass options to
        # Fiber.schedule, handle each option separately.
      else
        scheduler.singleton_class.prepend(FiberScheduler::Compatibility)

        case type
        when :blocking
          fiber = Fiber.new(blocking: true) do
            FiberScheduler::Compatibility.set_internal!
            yield
          end
          fiber.tap(&:resume)

        when :waiting
          parent = Fiber.current
          finished = false # prevents races
          blocking = false # prevents #unblock-ing a fiber that never blocked

          fiber = Fiber.schedule do
            FiberScheduler::Compatibility.set_internal!
            yield
          ensure
            finished = true
            scheduler.unblock(nil, parent) if blocking
          end

          if Fiber.blocking?
            # In a blocking fiber, which is potentially also a loop fiber so
            # there's nothing we can transfer to. Run other fibers (or just
            # block) until waiting fiber finishes.
            until finished
              scheduler.run_once
            end
          elsif !finished
            blocking = true
            scheduler.block(nil, nil)
          end

          fiber

        when :volatile
          scheduler.unblock(nil, Fiber.current)

          fiber = Fiber.new(blocking: false) do
            FiberScheduler::Compatibility.set_internal!
            yield
          rescue FiberScheduler::Compatibility::Close
            # Fiber scheduler is closing.
          ensure
            scheduler._volatile.delete(Fiber.current)
          end
          scheduler._volatile[fiber] = nil
          fiber.tap(&:transfer)

        when nil
          Fiber.schedule do
            FiberScheduler::Compatibility.set_internal!
            yield
          end

        else
          raise "Unknown type"
        end
      end
    end
  end
end

class FiberScheduler
  def initialize
    @fiber = Fiber.current
    @selector =
      if defined?(IO::Event)
        IO::Event::Selector.new(@fiber)
      else
        Selector.new(@fiber)
      end
    @timeouts = Timeouts.new

    @count = 0
    @nested = []
  end

  def run
    while @count > 0
      run_once
    end
  end

  def run_once
    if @nested.empty?
      @selector.select(@timeouts.interval)
      @timeouts.call
    else
      while @nested.any?
        fiber = @nested.pop
        fiber.transfer
      end
    end
  end

  # Fiber::SchedulerInterface methods below

  def close
    return unless @selector

    begin
      run
    ensure
      @selector.close
      @selector = nil
    end
  end

  def block(blocker, duration = nil)
    return @selector.transfer unless duration

    @timeouts.timeout(duration, method: :transfer) do
      @selector.transfer
    end
  end

  def unblock(blocker, fiber)
    @selector.push(fiber)
  end

  def kernel_sleep(duration = nil)
    return @selector.transfer unless duration

    block(:sleep, duration)
  end

  def address_resolve(hostname)
    Resolv.getaddresses(hostname)
  end

  def io_wait(io, events, duration = nil)
    return @selector.io_wait(Fiber.current, io, events) unless duration

    @timeouts.timeout(duration, method: :transfer) do
      @selector.io_wait(Fiber.current, io, events)
    end
  end

  def io_read(io, buffer, length, offset = 0)
    @selector.io_read(Fiber.current, io, buffer, length, offset)
  end

  def io_write(io, buffer, length, offset = 0)
    @selector.io_write(Fiber.current, io, buffer, length, offset)
  end

  def process_wait(pid, flags)
    @selector.process_wait(Fiber.current, pid, flags)
  end

  def timeout_after(duration, exception = Timeout::Error, message = "timeout", &block)
    @timeouts.timeout(duration, exception, message, &block)
  end

  def fiber(type = nil, &block)
    current = Fiber.current

    case type
    when :blocking
      Fiber.new(blocking: true, &block).tap(&:resume)

    when :waiting
      finished = false # prevents races
      fiber = Fiber.new(blocking: false) do
        @count += 1
        block.call
      ensure
        @count -= 1
        finished = true
        # Resume waiting parent fiber
        current.transfer
      end
      fiber.transfer

      # Current fiber is waiting until waiting fiber finishes.
      if current == @fiber
        # In a top-level fiber, there's nothing we can transfer to, so run
        # other fibers (or just block) until waiting fiber finishes.
        until finished
          run_once
        end
      elsif !finished
        @selector.transfer
      end

      fiber

    when :volatile
      if current != @fiber
        # nested Fiber.schedule
        @nested << current
      end

      Fiber.new(blocking: false, &block).tap(&:transfer)

    when nil
      if current != @fiber
        # nested Fiber.schedule
        @nested << current
      end

      fiber = Fiber.new(blocking: false) do
        @count += 1
        block.call
      ensure
        @count -= 1
      end
      fiber.tap(&:transfer)

    else
      raise "Unknown type"
    end
  end
end
