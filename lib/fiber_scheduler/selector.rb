class FiberScheduler
  class Selector
    def initialize(loop)
      @loop = loop

      @waiting = Hash.new.compare_by_identity

      @blocked = false

      @ready = Queue.new
      @interrupt = Interrupt.attach(self)
    end

    attr :loop

    # If the event loop is currently blocked,
    def wakeup
      if @blocked
        @interrupt.signal

        return true
      end

      return false
    end

    def close
      @interrupt.close

      @loop = nil
      @waiting = nil
    end

    Optional = Struct.new(:fiber) do
      def transfer(*arguments)
        fiber&.transfer(*arguments)
      end

      def alive?
        fiber&.alive?
      end

      def nullify
        self.fiber = nil
      end
    end

    # Transfer from the current fiber to the event loop.
    def transfer
      @loop.transfer
    end

    # Transfer from the current fiber to the specified fiber. Put the current fiber into the ready list.
    def resume(fiber, *arguments)
      optional = Optional.new(Fiber.current)
      @ready.push(optional)

      fiber.transfer(*arguments)
    ensure
      optional.nullify
    end

    # Yield from the current fiber back to the event loop. Put the current fiber into the ready list.
    def yield
      optional = Optional.new(Fiber.current)
      @ready.push(optional)

      @loop.transfer
    ensure
      optional.nullify
    end

    # Append the given fiber into the ready list.
    def push(fiber)
      @ready.push(fiber)
    end

    # Transfer to the given fiber and raise an exception. Put the current fiber into the ready list.
    def raise(fiber, *arguments)
      optional = Optional.new(Fiber.current)
      @ready.push(optional)

      fiber.raise(*arguments)
    ensure
      optional.nullify
    end

    def ready?
      !@ready.empty?
    end

    Waiter = Struct.new(:fiber, :events, :tail) do
      def alive?
        self.fiber&.alive?
      end

      def transfer(events)
        if fiber = self.fiber
          self.fiber = nil

          fiber.transfer(events & self.events) if fiber.alive?
        end

        self.tail&.transfer(events)
      end

      def invalidate
        self.fiber = nil
      end

      def each(&block)
        if fiber = self.fiber
          yield fiber, self.events
        end

        self.tail&.each(&block)
      end
    end

    def io_wait(fiber, io, events)
      waiter = @waiting[io] = Waiter.new(fiber, events, @waiting[io])

      @loop.transfer
    ensure
      waiter&.invalidate
    end

    if IO.const_defined?(:Buffer)
      EAGAIN = Errno::EAGAIN::Errno

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

    private def pop_ready
      unless @ready.empty?
        count = @ready.size

        count.times do
          fiber = @ready.pop
          fiber.transfer if fiber.alive?
        end

        return true
      end
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

    private def blocking(&block)
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

    # Send a sigle byte interrupt.
    def signal
      @output.write('.')
      @output.flush
    end

    def close
      @input.close
      @output.close
      # @fiber.raise(::Interrupt)
    end
  end
end
