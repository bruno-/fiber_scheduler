require "socket"

RSpec.shared_examples FiberSchedulerSpec::SocketIO do
  include_context FiberSchedulerSpec::Context

  context "UNIXSocket.pair" do
    let(:order) { [] }
    let(:pair) { UNIXSocket.pair }
    let(:reader) { pair.first }
    let(:writer) { pair.last }
    let(:messages) { [] }
    let(:sent) { "ruby" }
    let(:received) { messages.first }

    def operations
      Fiber.schedule do
        order << 1
        messages << reader.read(sent.size)
        reader.close
        order << 6
      end

      order << 2

      Fiber.schedule do
        order << 3
        writer.write(sent)
        writer.close
        order << 4
      end
      order << 5
    end

    it "calls #io_read and #io_write" do
      expect_any_instance_of(scheduler_class)
        .to receive(:io_read).once
        .and_call_original
      expect_any_instance_of(scheduler_class)
        .to receive(:io_write).once
        .and_call_original

      setup
    end

    it "writes and reads a message" do
      setup

      expect(received).to eq sent
    end

    it "behaves async" do
      setup

      expect(order).to eq (1..6).to_a
    end
  end
end

RSpec.describe FiberScheduler do
  describe "socket IO" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::SocketIO
    end

    context "with block setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples FiberSchedulerSpec::SocketIO
    end
  end
end
