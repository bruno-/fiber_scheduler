require "fiber_scheduler_spec/context"

RSpec.describe FiberScheduler do
  describe "waiting fiber" do
    include_context FiberSchedulerSpec::Context

    shared_examples :waiting_fiber_schedule do
      let(:order) { [] }

      context "when scheduled in a top-level fiber" do
        def operations
          Fiber.schedule do
            order << 1
            sleep 0.01
            order << 4
          end

          order << 2

          Fiber.schedule(:waiting) do
            order << 3
            sleep 0.01
            order << 5
          end

          order << 6

          Fiber.schedule do
            order << 7
            sleep 0.01
            order << 9
          end

          order << 8
        end

        it "stops the parent fiber until the child finishes" do
          setup

          expect(order).to eq (1..9).to_a
        end
      end

      context "when scheduled in a nested non-waiting fiber" do
        def operations
          Fiber.schedule do
            order << 1
            sleep 0.01
            order << 8
          end

          order << 2

          Fiber.schedule do
            order << 3

            Fiber.schedule(:waiting) do
              order << 4
              sleep 0.01
              order << 9
            end

            order << 10
          end

          order << 5

          Fiber.schedule do
            order << 6
            sleep 0.01
            order << 11
          end

          order << 7
        end

        it "stops the parent fiber until the child finishes" do
          setup

          expect(order).to eq (1..11).to_a
        end
      end

      context "when scheduled in a nested waiting fiber" do
        def operations
          Fiber.schedule do
            order << 1
            sleep 0.01
            order << 5
          end

          order << 2

          Fiber.schedule(:waiting) do
            order << 3

            Fiber.schedule(:waiting) do
              order << 4
              sleep 0.01
              order << 6
            end

            order << 7
          end

          order << 8

          Fiber.schedule do
            order << 9
            sleep 0.01
            order << 11
          end

          order << 10
        end

        it "stops the parent fiber until the child finishes" do
          setup

          expect(order).to eq (1..11).to_a
        end
      end
    end

    context "with default setup" do
      include_examples :waiting_fiber_schedule
    end

    context "with block setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples :waiting_fiber_schedule
    end
  end
end
