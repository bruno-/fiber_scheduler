require "fiber/scheduler"
require "timeout"

RSpec.describe "#timeout_after" do
  context "Timeout.timeout" do
    it "" do
      Thread.new do
        start_time = nil
        order = []

        Fiber::Scheduler.call do
          start_time = Time.now
          Fiber.schedule do
            begin
              order << 1
              Timeout.timeout(0.001) do
                order << 2
                sleep 1
              end
            rescue Timeout::Error
              order << 4
            end
          end
          order << 3
        end

        duration = Time.now - start_time
        p order
        p duration
        expect(duration).to be >= 0.001
        expect(duration).to be < 0.01
        expect(order).to eq [1, 2, 3, 4]
      end.join
    end
  end
end
