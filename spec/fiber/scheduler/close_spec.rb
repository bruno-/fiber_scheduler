require "fiber/scheduler"

RSpec.describe "#close" do
  context "without #run" do
    it "" do
      order = []

      Thread.new do
        scheduler = Fiber::Scheduler.new

        expect(scheduler)
          .to receive(:close).once
          .and_call_original

        Fiber.set_scheduler(scheduler)

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
        scheduler = Fiber::Scheduler.new

        expect(scheduler)
          .to receive(:close).once
          .and_call_original

        Fiber.set_scheduler(scheduler)

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
