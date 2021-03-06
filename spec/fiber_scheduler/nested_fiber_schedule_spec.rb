require "fiber_scheduler_spec/context"

RSpec.describe FiberScheduler do
  describe "nested Fiber.schedule" do
    shared_examples :nested_fiber_schedule do
      include_context FiberSchedulerSpec::Context

      let(:order) { [] }

      context "with only sync operations" do
        def operations
          Fiber.schedule do
            order << 1
            Fiber.schedule do
              order << 2
            end
            order << 3
          end
        end

        it "behaves sync" do
          setup

          expect(order).to eq [1, 2, 3]
        end
      end

      context "with async operations" do
        def operations
          Fiber.schedule do
            order << 1
            Fiber.schedule do
              order << 2
              sleep 0
              order << 7
            end
            order << 6
          end

          order << 3

          Fiber.schedule do
            order << 4
          end

          order << 5
        end

        it "behaves async" do
          setup

          expect(order).to eq (1..7).to_a
        end
      end
    end

    context "with default setup" do
      include_examples :nested_fiber_schedule
    end

    context "with block setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples :nested_fiber_schedule
    end
  end
end
