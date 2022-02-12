RSpec.describe FiberScheduler::Timeouts do
  describe "#call" do
    include_context FiberSchedulerSpec::Context
    let(:order) { [] }
    let(:scheduler_class) { FiberScheduler }
    let(:indices) { (-10..10).to_a }

    context "with timeouts added randomly" do
      def operations
        indices.shuffle.each do |index|
          Fiber.schedule do
            Fiber.scheduler.timeout_after(index.fdiv(100)) do
              # Sleep will timeout and add to 'order'
              sleep
            rescue FiberScheduler::Timeout::Error
              order << index
            end
          end
        end
      end

      it "runs timeouts in order" do
        setup
        sleep 0.11

        expect(order).to eq indices
      end
    end

    context "when timeouts are disabled" do
      def operations
        indices.each do |index|
          Fiber.schedule do
            Fiber.scheduler.timeout_after(index.fdiv(100)) do
              # Even index timeouts will timeout and add to 'order'.
              # Odd index timeouts are disabled and will not add to 'order'.
              sleep if (index % 2).zero?
            rescue FiberScheduler::Timeout::Error
              order << index
            end
          end
        end
      end

      it "does not run disabled timeouts" do
        setup
        sleep 0.11

        expect(order).to eq(-10.step(10, 2).to_a)
      end
    end
  end
end
