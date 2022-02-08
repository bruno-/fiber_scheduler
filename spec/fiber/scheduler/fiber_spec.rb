require "fiber/scheduler"

RSpec.describe "#fiber" do
  context "Fiber.schedule" do
    it "" do
      Thread.new do
        Fiber::Scheduler.call do
          expect {
            fiber = Fiber.schedule {}
            expect(fiber).not_to be_blocking
          }.to change {
            ObjectSpace.each_object(Fiber).count
          }.by(1)
        end
      end.join
    end
  end
end
