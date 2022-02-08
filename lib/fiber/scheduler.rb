require "io/event"
require "timers"
require "resolv"

class Fiber
  class Scheduler
    TimeoutError = Class.new(RuntimeError)

    def self.call(&block)
      scheduler = new
      Fiber.set_scheduler(scheduler)
      block.call

      scheduler.run
    ensure
      Fiber.set_scheduler(nil)
    end

    def initialize
      @timers = Timers::Group.new

      @selector = IO::Event::Selector.new(Fiber.current)
      @thread = Thread.current

      @blocked = 0
      @count = 0
    end

    def finished?
      @blocked.zero?
    end

    def close
      self.run

      Kernel.raise("Closing scheduler with blocked operations!") if @blocked > 0

      # We depend on GVL for consistency:
      @selector&.close
      @selector = nil
    end

    def closed?
      @selector.nil?
    end

    # Transfer from the calling fiber to the event loop.
    def transfer
      @selector.transfer
    end

    # Yield the current fiber and resume it on the next iteration of the event loop.
    def yield
      @selector.yield
    end

    # Schedule a fiber (or equivalent object) to be resumed on the next loop through the reactor.
    # @parameter fiber [Fiber | Object] The object to be resumed on the next iteration of the run-loop.
    def push(fiber)
      @selector.push(fiber)
    end

    def raise(*arguments)
      @selector.raise(*arguments)
    end

    def resume(fiber, *arguments)
      if Fiber.scheduler
        @selector.resume(fiber, *arguments)
      else
        @selector.push(fiber)
      end
    end

    # Invoked when a fiber tries to perform a blocking operation which cannot continue. A corresponding call {unblock} must be performed to allow this fiber to continue.
    # @asynchronous May only be called on same thread as fiber scheduler.
    def block(blocker, timeout)
      $stderr.puts "block(#{blocker}, #{Fiber.current}, #{timeout})"
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
        # puts "in #block\n"
      ensure
        @blocked -= 1
      end
    ensure
      timer&.cancel
    end

    # @asynchronous May be called from any thread.
    def unblock(blocker, fiber)
      # $stderr.puts "unblock(#{blocker}, #{fiber})"

      # This operation is protected by the GVL:
      @selector.push(fiber)
      @thread.raise(Errno::EINTR)
    end

    # @asynchronous May be non-blocking..
    def kernel_sleep(duration = nil)
      puts "#kernel_sleep #{Fiber.current.inspect}"
      if duration
        self.block(nil, duration)
      else
        self.transfer
      end
    end

    # @asynchronous May be non-blocking..
    def address_resolve(hostname)
      @blocked += 1
      ::Resolv.getaddresses(hostname)
    ensure
      @blocked -= 1
    end

    # @asynchronous May be non-blocking..
    def io_wait(io, events, timeout = nil)
      puts "!!in io_wait\n"
      fiber = Fiber.current

      if timeout
        timer = @timers.after(timeout) do
          fiber.raise(TimeoutError)
        end
      end

      events = @selector.io_wait(fiber, io, events)

      return events
    rescue TimeoutError
      return false
    ensure
      timer&.cancel
    end

    def io_read(io, buffer, length)
      puts "!!in io_read\n"
      @blocked += 1
      result = @selector.io_read(Fiber.current, io, buffer, length)
      puts "!!in after io_read, result: #{result.inspect}\n"
      result
    ensure
      @blocked -= 1
    end

    def io_write(io, buffer, length)
      # @blocked += 1
      @selector.io_write(Fiber.current, io, buffer, length)
    # ensure
    #   @blocked -= 1
    end

    # Wait for the specified process ID to exit.
    # @parameter pid [Integer] The process ID to wait for.
    # @parameter flags [Integer] A bit-mask of flags suitable for `Process::Status.wait`.
    # @returns [Process::Status] A process status instance.
    # @asynchronous May be non-blocking..
    def process_wait(pid, flags)
      puts "#{Process.clock_gettime(Process::CLOCK_MONOTONIC)} in #process wait\n"
      @blocked += 1
      pid = @selector.process_wait(Fiber.current, pid, flags)
      puts "#{Process.clock_gettime(Process::CLOCK_MONOTONIC)} after #process wait, pid #{pid}\n"
      return pid
    ensure
      @blocked -= 1
    end

    # Invoke the block, but after the specified timeout, raise {TimeoutError} in any currenly blocking operation. If the block runs to completion before the timeout occurs or there are no non-blocking operations after the timeout expires, the code will complete without any exception.
    # @parameter duration [Numeric] The time in seconds, in which the task should complete.
    def timeout_after(timeout, exception = TimeoutError, message = "execution expired", &block)
      fiber = Fiber.current

      timer = @timers.after(timeout) do
        if fiber.alive?
          fiber.raise(exception, message)
        end
      end

      yield timer
    ensure
      timer.cancel if timer
    end

    # Run one iteration of the event loop.
    # @parameter timeout [Float | Nil] The maximum timeout, or if nil, indefinite.
    # @returns [Boolean] Whether there is more work to do.
    def run_once(timeout = nil)
      Kernel.raise("Running scheduler on non-blocking fiber!") unless Fiber.blocking?

      # If we are finished, we stop the task tree and exit:
      if self.finished?
        puts "#{Process.clock_gettime(Process::CLOCK_MONOTONIC)} finished, blocked is #{@blocked}"
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

      begin
        Thread.handle_interrupt(Errno::EINTR => :on_blocking) do
          puts "running @selector.select(#{interval.inspect})"
          @selector.select(interval)
          puts "after @selector.select(#{interval.inspect})"
        end
      rescue Errno::EINTR
        # Ignore.
      end

      @timers.fire

      # The reactor still has work to do:
      return true
    end

    # Run the reactor until all tasks are finished. Proxies arguments to {#async} immediately before entering the loop, if a block is provided.
    def run
      Kernel.raise(RuntimeError, 'Reactor has been closed') if @selector.nil?

      Thread.handle_interrupt(Errno::EINTR => :never, Interrupt => :never) do
        while self.run_once
          # Event loop.
          if Thread.pending_interrupt?
            break
          end
        end
      end
    end

    # Start an asynchronous task within the specified reactor. The task will be
    # executed until the first blocking call, at which point it will yield and
    # and this method will return.
    def fiber(&block)
      fiber = Fiber.new(blocking: false, &block)
      puts "Creating fiber #{fiber.inspect}"
      @count += 1
      fiber.tap(&:transfer)
    ensure
      @count -= 1
    end
  end
end
