require "resolv"
require_relative "fiber_scheduler/selector"
require_relative "fiber_scheduler/timeouts"

begin
  # Use io/event selector if available
  require "io/event"
rescue LoadError
end

module Kernel
  def FiberScheduler(blocking: false, waiting: true, &block)
    if Fiber.scheduler.nil?
      scheduler = FiberScheduler.new
      Fiber.set_scheduler(scheduler)

      begin
        yield
        scheduler.close
      ensure
        Fiber.set_scheduler(nil)
      end

    else
      scheduler = Fiber.scheduler
      # Fiber.scheduler already set, just schedule a fiber.
      if scheduler.is_a?(FiberScheduler)
        # The default waiting is 'true' as that is the most intuitive behavior
        # for a nested FiberScheduler call.
        Fiber.schedule(blocking: blocking, waiting: waiting, &block)

      else
        # Unknown fiber scheduler class; can't just pass options to
        # Fiber.schedule, handle each option separately.
        if blocking
          Fiber.new(blocking: true, &block).tap(&:resume)

        elsif waiting
          current = Fiber.current
          finished = false # prevents races
          fiber = Fiber.schedule do
            block.call
          ensure
            # Resume waiting parent fiber
            finished = true
            scheduler.unblock(nil, current)
          end

          if Fiber.blocking?
            # In a blocking fiber, which is potentially also a loopo fiber so
            # there's nothing we can transfer to. Run other fibers (or just
            # block) until waiting fiber finishes.
            until finished
              scheduler.run_once
            end
          else
            scheduler.block(nil, nil) unless finished
          end

        else
          Fiber.schedule(&block)
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
        IO::Event::Selector.new(Fiber.current)
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

  def io_read(io, buffer, length)
    @selector.io_read(Fiber.current, io, buffer, length)
  end

  def io_write(io, buffer, length)
    @selector.io_write(Fiber.current, io, buffer, length)
  end

  def process_wait(pid, flags)
    @selector.process_wait(Fiber.current, pid, flags)
  end

  def timeout_after(duration, exception = Timeout::Error, message = "timeout", &block)
    @timeouts.timeout(duration, exception, message, &block)
  end

  def fiber(blocking: false, waiting: false, &block)
    current = Fiber.current

    if blocking
      # All fibers wait on a blocking fiber, so 'waiting' option is ignored.
      Fiber.new(blocking: true, &block).tap(&:resume)
    elsif waiting
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
      else
        @selector.transfer unless finished
      end

      fiber
    else
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
    end
  end
end
