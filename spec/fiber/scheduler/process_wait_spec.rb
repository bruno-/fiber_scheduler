require "fiber/scheduler"

RSpec.describe "#process_wait" do
  context "Kernel#system" do
    it "" do
      Thread.new do
        runs = 0
        start_time = nil

        Fiber::Scheduler.call do
          start_time = Time.now
          Fiber.schedule do
            Process.wait(spawn("sleep 0.1"))
            runs += 1
          end

          Fiber.schedule do
            Process.wait(spawn("sleep 0.1"))
            runs += 1
          end
        end

        expect(Time.now - start_time).to be >= 0.1
        expect(Time.now - start_time).to be < 0.15
        expect(runs).to eq 2
      end.join
    end
  end
end
