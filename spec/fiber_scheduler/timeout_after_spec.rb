require "timeout"

RSpec.shared_examples FiberSchedulerSpec::TimeoutAfter do
  include_context FiberSchedulerSpec::Context

  context "Timeout.timeout" do
    let(:order) { [] }
    let(:times) { [] }
    let(:duration) { times[1] - times[0] }
    let(:sleep_duration) { 0.01 }
    let(:operations) do
      -> do
        times << Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Fiber.schedule do
          begin
            order << 1
            Timeout.timeout(timeout) do
              order << 2
              sleep sleep_duration
              order << 4
            end
            order << 5
          rescue Timeout::Error
            order << 6
          end
          times << Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
        order << 3
      end
    end

    context "when the operation times out" do
      let(:timeout) { 0.001 }

      it "calls #timeout_after" do
        expect_any_instance_of(scheduler_class)
          .to receive(:timeout_after)
          .and_call_original

        setup.call
      end

      it "behaves async" do
        setup.call

        expect(order).to eq [1, 2, 3, 6]
      end

      it "times out early" do
        setup.call

        expect(duration).to be >= timeout
        expect(duration).to be < (timeout * 10)
      end
    end

    context "when the operation doesn't time out" do
      let(:timeout) { 0.1 }

      it "calls #timeout_after" do
        expect_any_instance_of(scheduler_class)
          .to receive(:timeout_after)
          .and_call_original

        setup.call
      end

      it "behaves async" do
        setup.call

        expect(order).to eq (1..5).to_a
      end

      it "finishes the operation" do
        setup.call

        expect(duration).to be >= sleep_duration
        expect(duration).to be < (sleep_duration * 1.5)
      end
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
          FiberScheduler do
            operations.call
          end
        end
      end

      include_examples FiberSchedulerSpec::TimeoutAfter
    end
  end
end
