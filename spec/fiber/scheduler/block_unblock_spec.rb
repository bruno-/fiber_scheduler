require "fiber/scheduler"

RSpec.describe "#block #unblock" do
  context "Thread::Queue" do
    let(:item) { "item" }

    it "" do
      order = []
      queue = Thread::Queue.new
      popped_item = nil

      Thread.new do
        Fiber::Scheduler.call do
          Fiber.schedule do
            order << 1
            popped_item = queue.pop
            order << 5
          end

          order << 2

          Fiber.schedule do
            order << 3
            queue.push(item)
            order << 4
          end
        end
      end.join

      expect(popped_item).to eq item
      expect(order).to eq (1..5).to_a
    end
  end
end
