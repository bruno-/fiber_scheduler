require "fiber/scheduler"

RSpec.describe "#io_wait" do
  context "UNIXSocket#wait_readable" do
    it "" do
      Thread.new do
        order = []
        input, output = UNIXSocket.pair

        Fiber::Scheduler.call do
          Fiber.schedule do
            order << 1
            input.wait_readable
            input.close
            order << 6
          end

          order << 2

          Fiber.schedule do
            order << 3
            output.write(".")
            output.close
            order << 4
          end
          order << 5
        end
        order << 7

        expect(order).to eq (1..7).to_a
      end.join
    end
  end
end
