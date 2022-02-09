require "fiber/scheduler"

RSpec.shared_examples FiberSchedulerSpec::Fiber do
  include_context FiberSchedulerSpec::Context

  context "Fiber.schedule" do
    let(:fibers) { [] }
    let(:fiber) { fibers.first }

    let(:operations) do
      -> do
        fibers << Fiber.schedule {}
      end
    end

    it "calls #fiber" do
      expect_any_instance_of(scheduler_class)
        .to receive(:fiber).once
        .and_call_original

      setup.call
    end

    it "creates a fiber" do
      # If only main fiber exists `Fiber.current` creates another fiber:
      # https://github.com/ruby/ruby/blob/67f4729ff0b0493ad82486b2f797a5c2b3ee20a6/cont.c#L2170-L2172
      # We're pre-emptively doing that so that ObjectSpace assertion below
      # works.
      Fiber.current

      expect {
        setup.call
      }.to change {
        ObjectSpace.each_object(Fiber).count
      }.by(1)
    end

    it "creates a non-blocking fiber" do
      setup.call

      expect(fiber).to be_a Fiber
      expect(fiber).not_to be_blocking
    end
  end
end

RSpec.describe Fiber::Scheduler do
  describe "#close" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::Fiber
    end

    context "with block setup" do
      let(:setup) do
        -> do
          described_class.schedule do
            operations.call
          end
        end
      end

      include_examples FiberSchedulerSpec::Fiber
    end
  end
end
