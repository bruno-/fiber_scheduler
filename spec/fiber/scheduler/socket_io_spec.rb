require "fiber/scheduler"
require "socket"

RSpec.shared_examples FiberSchedulerSpec::SocketIO do
  include_context FiberSchedulerSpec::Context

  context "UNIXSocket.pair" do
    let(:order) { [] }
    let(:pair) { UNIXSocket.pair }
    let(:input) { pair.first }
    let(:output) { pair.last }
    let(:messages) { [] }
    let(:sent) { "ruby" }
    let(:received) { messages.first }

    let(:operations) do
      -> do
        Fiber.schedule do
          order << 1
          messages << input.read(sent.size)
          input.close
          order << 6
        end

        order << 2

        Fiber.schedule do
          order << 3
          output.write(sent)
          output.close
          order << 4
        end
        order << 5
      end
    end

    it "calls #io_read and #io_write" do
      expect_any_instance_of(scheduler_class)
        .to receive(:io_read).once
        .and_call_original
      expect_any_instance_of(scheduler_class)
        .to receive(:io_write).once
        .and_call_original

      setup.call
    end

    it "writes and reads a message" do
      setup.call

      expect(received).to eq sent
    end

    it "behaves async" do
      setup.call

      expect(order).to eq (1..6).to_a
    end
  end
end

RSpec.describe Fiber::Scheduler do
  describe "socket IO" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::SocketIO
    end

    context "with block setup" do
      let(:setup) do
        -> do
          described_class.schedule do
            operations.call
          end
        end
      end

      include_examples FiberSchedulerSpec::SocketIO
    end
  end
end
