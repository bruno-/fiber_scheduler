require "timeout"

RSpec.shared_examples FiberSchedulerSpec::TimeoutAfter do
  include_context FiberSchedulerSpec::Context

  context "Timeout.timeout" do
    let(:order) { [] }
    let(:times) { [] }
    let(:timeout) { 0.001 }
    let(:duration) { times[1] - times[0] }
    let(:operations) do
      -> do
        times << Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Fiber.schedule do
          begin
            order << 1
            Timeout.timeout(timeout) do
              order << 2
              sleep 1
            end
          rescue Timeout::Error
            order << 4
            times << Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end
        end
        order << 3
      end
    end

    it "calls #timeout_after" do
      expect_any_instance_of(scheduler_class)
        .to receive(:timeout_after)
        .and_call_original

      setup.call
    end

    it "behaves async" do
      setup.call

      expect(order).to eq (1..4).to_a
    end

    it "times out early" do
      setup.call

      expect(duration).to be >= timeout
      expect(duration).to be < (timeout * 10)
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#timeout_after" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::TimeoutAfter
    end

    context "with block setup" do
      let(:setup) do
        -> do
          described_class.schedule do
            operations.call
          end
        end
      end

      include_examples FiberSchedulerSpec::TimeoutAfter
    end
  end
end
