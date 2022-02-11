class FiberScheduler
  class Selector
    EAGAIN = Errno::EAGAIN::Errno

    class Waiter
      def initialize(fiber, events, tail)
        @fiber = fiber
        @events = events
        @tail = tail
      end

      def alive?
        @fiber&.alive?
      end

      def transfer(events)
        if (fiber = @fiber)
          @fiber = nil

          fiber.transfer(events & @events) if fiber.alive?
        end

        @tail&.transfer(events)
      end

      def invalidate
        @fiber = nil
      end

      def each(&block)
        if (fiber = @fiber)
          yield fiber, @events
        end

        @tail&.each(&block)
      end
    end

    def initialize(fiber)
      @fiber = fiber

      @waiting = Hash.new.compare_by_identity

      @blocked = false

      @ready = Queue.new
      @interrupt = Interrupt.attach(self)
    end

    def close
      @interrupt.close

      @fiber = nil
      @waiting = nil
    end

    # Transfer from the current fiber to the event loop.
    def transfer
      @fiber.transfer
    end

    # Append the given fiber into the ready list.
    def push(fiber)
      @ready.push(fiber)
    end

    def io_wait(fiber, io, events)
      waiter = @waiting[io] = Waiter.new(fiber, events, @waiting[io])

      @loop.transfer
    ensure
      waiter&.invalidate
    end

    def io_read(fiber, io, buffer, length)
      offset = 0

      while true
        maximum_size = buffer.size - offset

        case result = blocking{io.read_nonblock(maximum_size, exception: false)}
        when :wait_readable
          if length > 0
            self.io_wait(fiber, io, IO::READABLE)
          else
            return -EAGAIN
          end
        when :wait_writable
          if length > 0
            self.io_wait(fiber, io, IO::WRITABLE)
          else
            return -EAGAIN
          end
        when nil
          break
        else
          buffer.set_string(result, offset)

          size = result.bytesize
          offset += size
          break if size >= length
          length -= size
        end
      end

      return offset
    end

    def io_write(fiber, io, buffer, length)
      offset = 0

      while true
        maximum_size = buffer.size - offset

        chunk = buffer.get_string(offset, maximum_size)
        case result = blocking{io.write_nonblock(chunk, exception: false)}
        when :wait_readable
          if length > 0
            self.io_wait(fiber, io, IO::READABLE)
          else
            return -EAGAIN
          end
        when :wait_writable
          if length > 0
            self.io_wait(fiber, io, IO::WRITABLE)
          else
            return -EAGAIN
          end
        else
          offset += result
          break if result >= length
          length -= result
        end
      end

      return offset
    end

    def process_wait(fiber, pid, flags)
      r, w = IO.pipe

      thread = Thread.new do
        Process::Status.wait(pid, flags)
      ensure
        w.close
      end

      self.io_wait(fiber, r, IO::READABLE)

      return thread.value
    ensure
      r.close
      w.close
      thread&.kill
    end

    def select(duration = nil)
      if pop_ready
        # If we have popped items from the ready list, they may influence the duration calculation, so we don't delay the event loop:
        duration = 0
      end

      readable = Array.new
      writable = Array.new

      @waiting.each do |io, waiter|
        waiter.each do |fiber, events|
          if (events & IO::READABLE) > 0
            readable << io
          end

          if (events & IO::WRITABLE) > 0
            writable << io
          end
        end
      end

      @blocked = true
      duration = 0 unless @ready.empty?
      readable, writable, _ = ::IO.select(readable, writable, nil, duration)
      @blocked = false

      ready = Hash.new(0)

      readable&.each do |io|
        ready[io] |= IO::READABLE
      end

      writable&.each do |io|
        ready[io] |= IO::WRITABLE
      end

      ready.each do |io, events|
        @waiting.delete(io).transfer(events)
      end

      return ready.size
    end

    private

    def pop_ready
      unless @ready.empty?
        count = @ready.size

        count.times do
          fiber = @ready.pop
          fiber.transfer if fiber.alive?
        end

        return true
      end
    end

    def blocking(&block)
      Fiber.new(blocking: true, &block).resume
    end
  end

  class Interrupt
    def self.attach(selector)
      self.new(selector)
    end

    def initialize(selector)
      @selector = selector
      @input, @output = ::IO.pipe

      @fiber = Fiber.new do
        while true
          if @selector.io_wait(@fiber, @input, IO::READABLE)
            @input.read_nonblock(1)
          end
        end
      end

      @fiber.transfer
    end

    def signal
      @output.write(".")
      @output.flush
    end

    def close
      @input.close
      @output.close
    end
  end
end
