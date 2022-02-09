require "io/event"
require "timers"
require "resolv"

module Kernel
  def FiberScheduler
    scheduler = ::FiberScheduler.new
    Fiber.set_scheduler(scheduler)
    yield

    scheduler.run
  ensure
    Fiber.set_scheduler(nil)
  end
end

class FiberScheduler
  TimeoutError = Class.new(RuntimeError)

  def initialize
    @timers = Timers::Group.new
    @selector = IO::Event::Selector.new(Fiber.current)

    @blocked = 0
    @count = 0
  end

  def close
    self.run

    raise("Closing scheduler with blocked operations!") if @blocked > 0

    # We depend on GVL for consistency:
    @selector&.close
    @selector = nil
  end

  def block(blocker, timeout)
    fiber = Fiber.current

    if timeout
      timer = @timers.after(timeout) do
        if fiber.alive?
          fiber.transfer(false)
        end
      end
    end

    begin
      @blocked += 1
      @selector.transfer
    ensure
      @blocked -= 1
    end
  ensure
    timer&.cancel
  end

  def unblock(blocker, fiber)
    @selector.push(fiber)
  end

  def kernel_sleep(duration = nil)
    if duration
      self.block(nil, duration)
    else
      @selector.transfer
    end
  end

  def address_resolve(hostname)
    @blocked += 1
    ::Resolv.getaddresses(hostname)
  ensure
    @blocked -= 1
  end

  def io_wait(io, events, timeout = nil)
    fiber = Fiber.current

    if timeout
      timer = @timers.after(timeout) do
        fiber.raise(TimeoutError)
      end
    end

    events =
      begin
        @blocked += 1
        @selector.io_wait(fiber, io, events)
      ensure
        @blocked -= 1
      end

    return events
  rescue TimeoutError
    return false
  ensure
    timer&.cancel
  end

  def io_read(io, buffer, length)
    @blocked += 1
    @selector.io_read(Fiber.current, io, buffer, length)
  ensure
    @blocked -= 1
  end

  def io_write(io, buffer, length)
    @selector.io_write(Fiber.current, io, buffer, length)
  end

  def process_wait(pid, flags)
    @blocked += 1
    @selector.process_wait(Fiber.current, pid, flags)
  ensure
    @blocked -= 1
  end

  def timeout_after(timeout, exception = TimeoutError, message = "execution expired", &block)
    fiber = Fiber.current

    timer = @timers.after(timeout) do
      if fiber.alive?
        fiber.raise(exception, message)
      end
    end

    @blocked += 1
    yield timeout
  ensure
    timer.cancel if timer
    @blocked -= 1
  end

  def run_once(timeout = nil)
    raise("Running scheduler on non-blocking fiber!") unless Fiber.blocking?

    if @blocked.zero?
      return false
    end

    interval = @timers.wait_interval

    # If there is no interval to wait (thus no timers), and no tasks, we could be done:
    if interval.nil?
      # Allow the user to specify a maximum interval if we would otherwise be sleeping indefinitely:
      interval = timeout
    elsif interval < 0
      # We have timers ready to fire, don't sleep in the selctor:
      interval = 0
    elsif timeout and interval > timeout
      interval = timeout
    end

    @selector.select(interval)

    @timers.fire

    return true
  end

  def run
    raise(RuntimeError, 'Reactor has been closed') if @selector.nil?

    while self.run_once
    end
  end

  def fiber(&block)
    fiber = Fiber.new(blocking: false, &block)
    @count += 1
    fiber.tap(&:transfer)
  ensure
    @count -= 1
  end
end
