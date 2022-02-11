RSpec.shared_examples FiberSchedulerSpec::Fiber do
  include_context FiberSchedulerSpec::Context

  context "Fiber.schedule" do
    let(:fibers) { [] }
    let(:fiber) { fibers.first }

    def operations
      fibers << Fiber.schedule {}
    end

    it "calls #fiber" do
      expect_any_instance_of(scheduler_class)
        .to receive(:fiber).once
        .and_call_original

      setup
    end

    it "creates a fiber" do
      begin
        # Prevent GC running inbetween two ObjectSpace calls.
        GC.disable

        before = ObjectSpace.each_object(Fiber).count
        setup
        after = ObjectSpace.each_object(Fiber).count

        # The after - before is > 1 with the built-in selector.
        expect(after - before).to be >= 1
      ensure
        GC.enable
      end
    end

    it "creates a non-blocking fiber" do
      setup

      expect(fiber).to be_a Fiber
      expect(fiber).not_to be_blocking
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#close" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::Fiber
    end

    context "with block setup" do
      def setup
        FiberScheduler do
          operations.call
        end
      end

      include_examples FiberSchedulerSpec::Fiber
    end
  end
end
