require "io/event"
require "timers"
require "resolv"

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

  def initialize
    @timers = Timers::Group.new
    @selector = IO::Event::Selector.new(Fiber.current)

    @count = 0
  end

  def run
    while @count > 0
      interval = @timers.wait_interval

      if interval && interval < 0
        # We have timers ready to fire, don't sleep in the selctor:
        interval = 0
      end

      @selector.select(interval)

      @timers.fire
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
    if timeout
      fiber = Fiber.current
      timer = @timers.after(timeout) do
        if fiber.alive?
          fiber.transfer(false)
        end
      end
    end

    @selector.transfer
  ensure
    timer&.cancel
  end

  def unblock(blocker, fiber)
    @selector.push(fiber)
  end

  def kernel_sleep(duration = nil)
    if duration
      block(Fiber.current, duration)
    else
      @selector.transfer
    end
  end

  def address_resolve(hostname)
    Resolv.getaddresses(hostname)
  end

  def io_wait(io, events, timeout = nil)
    fiber = Fiber.current
    if timeout
      timer = @timers.after(timeout) do
        fiber.raise(TimeoutError)
      end
    end

    @selector.io_wait(fiber, io, events)
  rescue TimeoutError
    return false
  ensure
    timer&.cancel
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

  def timeout_after(timeout, exception = TimeoutError, message = "execution expired", &block)
    fiber = Fiber.current
    timer = @timers.after(timeout) do
      if fiber.alive?
        fiber.raise(exception, message)
      end
    end

    yield timeout
  ensure
    timer.cancel if timer
  end

  def fiber(&block)
    fiber = Fiber.new(blocking: false) do
      @count += 1
      block.call
    ensure
      @count -= 1
    end

    fiber.tap(&:transfer)
  end
end
