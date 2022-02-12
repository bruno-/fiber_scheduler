require "async"

RSpec.describe FiberScheduler do
  shared_examples :async_compatibility do
    include_context FiberSchedulerSpec::Context

    let(:order) { [] }

    context "without FiberScheduler options" do
      it "behaves synchronous" do
        Async do |task|
          order << 1
          FiberScheduler do # default 'wait: true' option
            order << 2
            Fiber.schedule do
              order << 3
              sleep 0.001
              order << 7
            end

            order << 4

            Fiber.schedule do
              order << 5
              sleep 0.001
              order << 8
            end

            order << 6
            sleep 0.02
            order << 9
          end

          order << 10
        end

        expect(order).to eq (1..10).to_a
      end
    end

    context "with a blocking FiberScheduler" do
      it "blocks all other async tasks" do
        Async do |task|
          order << 1

          task.async do
            order << 2
            sleep 0.01
            order << 8
          end

          order << 3

          FiberScheduler(blocking: true) do
            order << 4
            Fiber.schedule do
              order << 5
              sleep 0.01
              order << 9
            end
            sleep 0.02
            order << 6
          end

          order << 7
        end

        expect(order).to eq (1..9).to_a
      end
    end

    context "with a non-waiting FiberScheduler" do
      it "behaves async" do
        Async do |task|
          order << 1

          task.async do
            order << 2
            sleep 0.01
            order << 8
          end

          order << 3

          FiberScheduler(wait: false) do
            order << 4
            Fiber.schedule do
              order << 5
              sleep 0.01
              order << 9
            end
            order << 7
            sleep 0.02
            order << 10
          end

          order << 6
        end

        expect(order).to eq (1..10).to_a
      end
    end
  end

  describe "async compatibility" do
  end
end
