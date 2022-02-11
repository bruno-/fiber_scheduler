require "io/event"
require "resolv"
require_relative "fiber_scheduler/timeouts"

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
  TimeoutError = Class.new(RuntimeError)

  def initialize
    @selector = IO::Event::Selector.new(Fiber.current)
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

    timeout = @timeouts.transfer_in(duration)
    begin
      @selector.transfer
    ensure
      timeout.disable
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

    timeout = @timeouts.transfer_in(duration)
    begin
      @selector.io_wait(Fiber.current, io, events)
    ensure
      timeout.disable
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

  def timeout_after(duration, exception = TimeoutError, message = "timeout")
    timeout = @timeouts.raise_in(duration, exception, message)
    begin
      yield duration
    ensure
      timeout.disable
    end
  end

  def fiber(&block)
    unless Fiber.blocking?
      # nested Fiber.schedule
      @nested << Fiber.current
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
