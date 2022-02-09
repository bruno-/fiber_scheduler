require "fiber/scheduler"

RSpec.describe "#io_wait" do
  context "UNIXSocket#wait_readable" do
    context "without a timeout" do
      it "" do
        Thread.new do
          order = []
          input, output = UNIXSocket.pair

          expect_any_instance_of(Fiber::Scheduler)
            .to receive(:io_wait).once
            .and_call_original

          Fiber::Scheduler.schedule do
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

    context "with a timeout" do
      it "" do
        Thread.new do
          order = []
          input, output = UNIXSocket.pair

          expect_any_instance_of(Fiber::Scheduler)
            .to receive(:io_wait).once
            .and_call_original

          Fiber::Scheduler.schedule do
            Fiber.schedule do
              order << 1
              input.wait_readable(0.001)
              order << 3
            end

            order << 2
          end

          order << 4
          input.close
          output.close

          expect(order).to eq (1..4).to_a
        end.join
      end
    end
  end
end
