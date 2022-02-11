require "io/event"
require "resolv"
require_relative "fiber_scheduler/triggers"

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
    @triggers = Triggers.new

    @count = 0
    @nested = []
  end

  def run
    while @count > 0
      if @nested.empty?
        @selector.select(@triggers.interval)
        @triggers.call
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

    trigger = @triggers.transfer_in(timeout)
    begin
      @selector.transfer
    ensure
      trigger.disable
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
    return @selector.io_wait(Fiber.current, io, events) unless timeout

    trigger = @triggers.transfer_in(timeout)
    begin
      @selector.io_wait(Fiber.current, io, events)
    ensure
      trigger.disable
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
    trigger = @triggers.raise_in(duration, exception, message)

    begin
      yield duration
    ensure
      trigger.disable
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
