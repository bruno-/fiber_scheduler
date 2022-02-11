RSpec.shared_examples FiberSchedulerSpec::KernelSleep do
  include_context FiberSchedulerSpec::Context

  context "Kernel.sleep" do
    let(:order) { [] }
    let(:times) { [] }
    let(:duration) { times[1] - times[0] }

    context "multiple sleep operations" do
      let(:interval) { 0.1 }

      def operations
        times << Process.clock_gettime(Process::CLOCK_MONOTONIC)

        Fiber.schedule do
          order << 1
          sleep interval
          order << 5
        end

        order << 2

        Fiber.schedule do
          order << 3
          sleep interval
          order << 6
        end

        order << 4
      end

      it "calls #kernel_sleep" do
        expect_any_instance_of(scheduler_class)
          .to receive(:kernel_sleep).exactly(2).times
          .and_call_original

        setup
      end

      it "behaves async" do
        setup

        expect(order).to eq (1..6).to_a
      end

      it "runs operations in parallel" do
        setup
        times << Process.clock_gettime(Process::CLOCK_MONOTONIC)

        expect(duration).to be >= interval
        expect(duration).to be < (interval * 1.2)
      end
    end

    context "sleep 0" do
      def operations
        times << Process.clock_gettime(Process::CLOCK_MONOTONIC)

        Fiber.schedule do
          order << 1
          sleep 0
          times << Process.clock_gettime(Process::CLOCK_MONOTONIC)
          order << 3
        end
        order << 2
      end

      it "calls #kernel_sleep" do
        expect_any_instance_of(scheduler_class)
          .to receive(:kernel_sleep).once
          .and_call_original

        setup
      end

      it "behaves async" do
        setup

        expect(order).to eq (1..3).to_a
      end

      it "runs the operation in no time" do
        setup

        # No sleeping was performed at all.
        expect(duration).to be < 0.0005
      end
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#io_wait" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::KernelSleep
    end

    context "with block setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples FiberSchedulerSpec::KernelSleep
    end
  end
end
