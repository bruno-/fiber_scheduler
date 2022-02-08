require "fiber/scheduler"
require "socket"

RSpec.describe "#io_wait" do
  context "UNIXSocket.pair" do
    let(:message) { "fiber scheduler" }

    it "" do
      Thread.new do
        order = []
        input, output = UNIXSocket.pair
        input_read = nil

        Fiber::Scheduler.call do
          Fiber.schedule do
            order << 1
            input_read = input.read(message.size)
            input.close
            order << 6
          end

          order << 2

          Fiber.schedule do
            order << 3
            # THIS fiber behaves synchronous!
            output.write(message)
            output.close
            order << 4
          end
          order << 5
        end
        order << 7

        expect(order).to eq (1..7).to_a
        expect(input_read).to eq message
      end.join
    end
  end
end
