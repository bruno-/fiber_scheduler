require "fiber/scheduler"

RSpec.describe "#close" do
  context "without #run" do
    it "" do
      order = []

      Thread.new do
        Fiber.set_scheduler(Fiber::Scheduler.new)

        Fiber.schedule do
          order << 1
        end
      end.join

      expect(order).to contain_exactly(1)
    end
  end

  context "with #run" do
    it "" do
      order = []

      Thread.new do
        Fiber.set_scheduler(Fiber::Scheduler.new)

        Fiber.schedule do
          order << 1
        end

        Fiber.scheduler.run

        Fiber.schedule do
          order << 2
        end
      end.join

      expect(order).to contain_exactly(1, 2)
    end
  end

  # TODO: should closing a scheduler also set Fiber.scheduler to nil?
end
