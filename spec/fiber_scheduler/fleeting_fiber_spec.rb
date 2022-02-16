require "fiber_scheduler_spec/context"

RSpec.describe FiberScheduler do
  describe "fleeting fiber" do
    include_context FiberSchedulerSpec::Context

    shared_examples :fleeting_fiber_schedule do
      let(:order) { [] }

      context "when scheduled in a top-level fiber" do
        def operations
          Fiber.schedule do
            order << 1
            sleep 0.001
            order << 5
          end

          order << 2

          Fiber.schedule(:fleeting) do
            order << 3
            sleep
            order << :this_line_never_runs
          end

          order << 4
        end

        it "never finishes" do
          setup

          expect(order).to eq (1..5).to_a
        end
      end

      context "when scheduled in a nested fiber" do
        def operations
          Fiber.schedule do
            order << 1
            sleep 0.001
            order << 7
          end

          order << 2

          Fiber.schedule do
            order << 3

            Fiber.schedule(:fleeting) do
              order << 4
              sleep
              order << :this_line_never_runs
            end

            order << 6
          end

          order << 5
        end

        it "never finishes" do
          setup

          expect(order).to eq (1..7).to_a
        end
      end

      context "when scheduled in a nested waiting fiber" do
        def operations
          Fiber.schedule do
            order << 1
            sleep 0.001
            order << 7
          end

          order << 2

          Fiber.schedule(:waiting) do
            order << 3

            Fiber.schedule(:fleeting) do
              order << 4
              sleep
              order << :this_line_never_runs
            end

            order << 5
          end

          order << 6
        end

        it "never finishes" do
          setup

          expect(order).to eq (1..7).to_a
        end
      end

      context "when a fleeting fiber ends fast" do
        def operations
          Fiber.schedule do
            order << 1
            sleep 0.01
            order << 6
          end

          order << 2

          Fiber.schedule(:fleeting) do
            order << 3
            sleep 0.001
            order << 5
          end

          order << 4
        end

        it "finishes" do
          setup

          expect(order).to eq (1..6).to_a
        end
      end
    end

    context "with default setup" do
      include_examples :fleeting_fiber_schedule
    end

    context "with block setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples :fleeting_fiber_schedule
    end
  end
end
