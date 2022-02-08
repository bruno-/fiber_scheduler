require "fiber/scheduler"
require "timeout"

RSpec.describe "#timeout_after" do
  context "Timeout.timeout" do
    it "" do
      Thread.new do
        start_time = nil
        order = []
        error = nil

        Fiber::Scheduler.call do
          start_time = Time.now
          Fiber.schedule do
            begin
              order << 1
              Timeout.timeout(0.001) do
                order << 2
                sleep 1
              end
            rescue => e
              order << 4
              error = e
            end
          end
          order << 3
        end

        duration = Time.now - start_time
        expect(duration).to be >= 0.001
        expect(duration).to be < 0.002
        expect(order).to eq [1, 2, 3, 4]
      end.join
    end
  end
end
