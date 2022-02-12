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

      @waiting = {}.compare_by_identity
      @ready = []
    end

    def close
      @fiber = nil
      @waiting = nil
      @ready = nil
    end

    def transfer
      @fiber.transfer
    end

    def push(fiber)
      @ready.push(fiber)
    end

    def io_wait(fiber, io, events)
      waiter = @waiting[io] = Waiter.new(fiber, events, @waiting[io])

      @fiber.transfer
    ensure
      waiter&.invalidate
    end

    def io_read(fiber, io, buffer, length)
      offset = 0

      loop do
        maximum_size = buffer.size - offset

        result = Fiber.new(blocking: true) {
          io.read_nonblock(maximum_size, exception: false)
        }.resume

        case result
        when :wait_readable
          if length > 0
            io_wait(fiber, io, IO::READABLE)
          else
            return -EAGAIN
          end
        when :wait_writable
          if length > 0
            io_wait(fiber, io, IO::WRITABLE)
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

      offset
    end

    def io_write(fiber, io, buffer, length)
      offset = 0

      loop do
        maximum_size = buffer.size - offset

        chunk = buffer.get_string(offset, maximum_size)
        result = Fiber.new(blocking: true) {
          io.write_nonblock(chunk, exception: false)
        }.resume

        case result
        when :wait_readable
          if length > 0
            io_wait(fiber, io, IO::READABLE)
          else
            return -EAGAIN
          end
        when :wait_writable
          if length > 0
            io_wait(fiber, io, IO::WRITABLE)
          else
            return -EAGAIN
          end
        else
          offset += result
          break if result >= length
          length -= result
        end
      end

      offset
    end

    def process_wait(fiber, pid, flags)
      reader, writer = IO.pipe

      thread = Thread.new do
        Process::Status.wait(pid, flags)
      ensure
        writer.close
      end

      io_wait(fiber, reader, IO::READABLE)

      thread.value
    ensure
      reader.close
      writer.close
      thread&.kill
    end

    def select(duration = nil)
      if @ready.any?
        # If we have popped items from the ready list, they may influence the
        # duration calculation, so we don't delay the event loop:
        duration = 0

        count = @ready.size
        count.times do
          fiber = @ready.shift
          fiber.transfer if fiber.alive?
        end
      end

      readable = []
      writable = []

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

      duration = 0 if @ready.any?
      readable, writable, _ = IO.select(readable, writable, nil, duration)

      ready = Hash.new(0)

      readable&.each do |io|
        ready[io] |= IO::READABLE
      end

      writable&.each do |io|
        ready[io] |= IO::WRITABLE
      end

      ready.each do |io, events|
        waiter = @waiting.delete(io)
        waiter.transfer(events)
      end

      ready.size
    end
  end
end
