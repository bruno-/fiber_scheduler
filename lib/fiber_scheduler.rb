require "io/event"
require "resolv"
require_relative "fiber_scheduler/timers"

module Kernel
  def FiberScheduler
    scheduler = FiberScheduler.new
    Fiber.set_scheduler(scheduler)
    yield

    scheduler.close
  ensure
    Fiber.set_scheduler(nil)
  end
end

class FiberScheduler
  TimeoutError = Class.new(RuntimeError)
  IOWaitTimeout = Class.new(TimeoutError)

  def initialize
    @selector = IO::Event::Selector.new(Fiber.current)
    @timers = Timers.new

    @count = 0
    @nested = []
  end

  def run
    while @count > 0
      if @nested.empty?
        @selector.select(@timers.interval)
        @timers.call
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

  def block(blocker, timeout)
    return @selector.transfer unless timeout

    fiber = Fiber.current
    timer = @timers.add(timeout) do
      fiber.transfer if fiber.alive?
    end

    begin
      @selector.transfer
    ensure
      timer.disable
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

  def io_wait(io, events, timeout = nil)
    fiber = Fiber.current
    return @selector.io_wait(fiber, io, events) unless timeout

    timer = @timers.add(timeout) do
      fiber.raise(IOWaitTimeout) if fiber.alive?
    end

    begin
      @selector.io_wait(fiber, io, events)
    rescue IOWaitTimeout
      false
    ensure
      timer.disable
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
    fiber = Fiber.current
    timer = @timers.add(duration) do
      fiber.raise(exception, message) if fiber.alive?
    end

    begin
      yield duration
    ensure
      timer.disable
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
