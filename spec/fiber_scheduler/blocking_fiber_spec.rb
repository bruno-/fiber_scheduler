RSpec.describe FiberScheduler do
  describe "blocking fiber" do
    include_context FiberSchedulerSpec::Context

    shared_examples :blocking_fiber_schedule do
      let(:order) { [] }

      context "when scheduled in a top-level fiber" do
        let(:operations) do
          -> do
            Fiber.schedule do
              order << 1
              sleep 0.01
              order << 6
            end

            order << 2

            Fiber.schedule(blocking: true) do
              order << 3
              sleep 0.01
              order << 4
            end

            order << 5
          end
        end

        it "stops all other fibers" do
          setup.call

          expect(order).to eq (1..6).to_a
        end
      end

      context "when scheduled in a nested fiber" do
        let(:operations) do
          -> do
            Fiber.schedule do
              order << 1
              sleep 0.01
              order << 8
            end

            order << 2

            Fiber.schedule do
              order << 3

              Fiber.schedule(blocking: true) do
                order << 4
                sleep 0.01
                order << 5
              end

              order << 6
            end

            order << 7
          end
        end

        it "stops all other fibers" do
          setup.call

          expect(order).to eq (1..8).to_a
        end
      end

      context "when scheduled in a nested waiting fiber" do
        let(:operations) do
          -> do
            Fiber.schedule do
              order << 1
              sleep 0.01
              order << 8
            end

            order << 2

            Fiber.schedule(wait: true) do
              order << 3

              Fiber.schedule(blocking: true) do
                order << 4
                sleep 0.01
                order << 5
              end

              order << 6
            end

            order << 7
          end
        end

        it "stops all other fibers" do
          setup.call

          expect(order).to eq (1..8).to_a
        end
      end
    end

    context "with default setup" do
      include_examples :blocking_fiber_schedule
    end

    context "with block setup" do
      let(:setup) do
        -> do
          FiberScheduler do
            operations.call
          end
        end
      end

      include_examples :blocking_fiber_schedule
    end
  end
end
