RSpec.shared_examples FiberSchedulerSpec::KernelSleep do
  include_context FiberSchedulerSpec::Context

  context "Kernel.sleep" do
    let(:interval) { 0.1 }
    let(:order) { [] }
    let(:times) { [] }
    let(:duration) { times[1] - times[0] }
    let(:operations) do
      -> do
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
    end

    it "calls #kernel_sleep" do
      expect_any_instance_of(scheduler_class)
        .to receive(:kernel_sleep).exactly(2).times
        .and_call_original

      setup.call
    end

    it "behaves async" do
      setup.call

      expect(order).to eq (1..6).to_a
    end

    it "runs operations in parallel" do
      setup.call
      times << Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect(duration).to be >= interval
      expect(duration).to be < (interval * 1.2)
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#io_wait" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::KernelSleep
    end

    context "with block setup" do
      let(:setup) do
        -> do
          described_class.schedule do
            operations.call
          end
        end
      end

      include_examples FiberSchedulerSpec::KernelSleep
    end
  end
end
