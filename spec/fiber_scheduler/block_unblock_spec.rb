RSpec.shared_examples FiberSchedulerSpec::BlockUnblock do
  include_context FiberSchedulerSpec::Context

  context "Addrinfo.getaddrinfo" do
    let(:order) { [] }
    let(:queue) { Thread::Queue.new }
    let(:item) { "item" }
    let(:popped_items) { [] }

    def operations
      Fiber.schedule do
        order << 1
        popped_items << queue.pop
        order << 6
      end

      order << 2

      Fiber.schedule do
        order << 3
        queue.push(item)
        order << 4
      end

      order << 5
    end

    it "calls #block and #unblock" do
      expect_any_instance_of(scheduler_class)
        .to receive(:block).once
        .and_call_original
      expect_any_instance_of(scheduler_class)
        .to receive(:unblock).once
        .and_call_original

      setup
    end

    it "behaves async" do
      setup

      expect(popped_items).to contain_exactly(item)
      expect(order).to eq (1..6).to_a
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#block #unblock" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::BlockUnblock
    end

    context "with #call setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples FiberSchedulerSpec::BlockUnblock
    end
  end
end
