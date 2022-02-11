RSpec.shared_examples FiberSchedulerSpec::Close do
  include_context FiberSchedulerSpec::Context

  # TODO: should closing a scheduler also set Fiber.scheduler to nil?
  context "without #run" do
    let(:order) { [] }

    def operations
      Fiber.schedule do
        order << 2
      end
      order << 1
    end

    # NOTE: this example does not use 'setup', #run should not be invoked
    if method_defined?(:default_setup)
      # skipping if user overrode setup
      it "calls #close" do
        expect(scheduler)
          .to receive(:close).once
          .and_call_original

        Thread.new do
          Fiber.set_scheduler(scheduler)

          operations
        end.join
      end
    end

    it "behaves async" do
      setup

      expect(order).to contain_exactly(1, 2)
    end
  end

  context "with #run" do
    let(:order) { [] }

    def operations
      Fiber.schedule do
        order << 2
      end

      order << 1
      Fiber.scheduler.run
      order << 3

      Fiber.schedule do
        order << 4
      end

      order << 5
    end

    it "calls #close" do
      expect(scheduler)
        .to receive(:close).once
        .and_call_original

      Thread.new do
        Fiber.set_scheduler(scheduler)
        operations
        scheduler.run
      end.join
    end

    it "behaves async" do
      setup

      expect(order).to contain_exactly(1, 2, 3, 4, 5)
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#close" do
    include_examples FiberSchedulerSpec::Close
  end
end
