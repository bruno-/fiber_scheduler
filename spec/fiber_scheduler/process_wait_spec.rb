RSpec.shared_examples FiberSchedulerSpec::ProcessWait do
  include_context FiberSchedulerSpec::Context

  context "Process.wait" do
    let(:interval_short) { 0.09 }
    let(:interval) { 0.1 }
    let(:order) { [] }
    let(:times) { [] }
    let(:duration) { times[1] - times[0] }
    def operations
      times << Process.clock_gettime(Process::CLOCK_MONOTONIC)

      Fiber.schedule do
        order << 1
        # This interval is shorter so we're certain it will finish before the
        # other fiber.
        Process.wait(spawn("sleep #{interval_short}"))
        order << 5
      end

      order << 2

      Fiber.schedule do
        order << 3
        Process.wait(spawn("sleep #{interval}"))
        order << 6
      end

      order << 4
    end

    it "calls #process_wait" do
      expect_any_instance_of(scheduler_class)
        .to receive(:process_wait).exactly(2).times
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
      expect(duration).to be < (interval * 1.5)
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#process_wait" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::ProcessWait
    end

    context "with block setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples FiberSchedulerSpec::ProcessWait
    end
  end
end
