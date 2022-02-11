require "resolv"
require_relative "fiber_scheduler/selector"
require_relative "fiber_scheduler/timeouts"

begin
  # Use io/event selector if available
  require "io/event"
rescue LoadError
end

module Kernel
  def FiberScheduler(&block)
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
      # Fiber.scheduler already set, just schedule a task.
      Fiber.schedule(&block)
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
        Selector.new(Fiber.current)
      end
    @timeouts = Timeouts.new

    @count = 0
    @nested = []
  end

  def run
    while @count > 0
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

  def block(blocker, duration)
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

  def fiber(blocking: false, &block)
    current = Fiber.current
    if current != @fiber
      # nested Fiber.schedule
      @nested << current
    end

    fiber = Fiber.new(blocking: blocking) do
      @count += 1
      block.call
    ensure
      @count -= 1
    end

    fiber.tap(&:transfer)
  end
end
