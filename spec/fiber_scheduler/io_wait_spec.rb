RSpec.shared_examples FiberSchedulerSpec::IOWait do
  include_context FiberSchedulerSpec::Context

  context "UNIXSocket#wait_readable" do
    context "without a timeout" do
      let(:order) { [] }
      let(:pair) { UNIXSocket.pair }
      let(:reader) { pair.first }
      let(:writer) { pair.last }
      let(:operations) do
        -> do
          Fiber.schedule do
            order << 1
            reader.wait_readable
            reader.close
            order << 6
          end

          order << 2

          Fiber.schedule do
            order << 3
            writer.write(".")
            writer.close
            order << 4
          end
          order << 5
        end
      end

      it "behaves async" do
        setup.call

        expect(order).to eq (1..6).to_a
      end

      it "calls #io_wait" do
        expect_any_instance_of(scheduler_class)
          .to receive(:io_wait).once
          .and_call_original

        setup.call
      end
    end

    context "with a timeout" do
      let(:order) { [] }
      let(:pair) { UNIXSocket.pair }
      let(:reader) { pair.first }
      let(:writer) { pair.last }
      let(:operations) do
        -> do
          Fiber.schedule do
            order << 1
            reader.wait_readable(0.001)
            order << 3
          end
          order << 2
        end
      end

      it "behaves async" do
        setup.call

        expect(order).to eq (1..3).to_a
      end

      it "calls #io_wait" do
        expect_any_instance_of(scheduler_class)
          .to receive(:io_wait).once
          .and_call_original

        setup.call
      end
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#io_wait" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::IOWait
    end

    context "with block setup" do
      let(:setup) do
        -> do
          FiberScheduler do
            operations.call
          end
        end
      end

      include_examples FiberSchedulerSpec::IOWait
    end
  end
end
