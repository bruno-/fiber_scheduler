RSpec.describe FiberScheduler do
  describe "nested FiberScheduler" do
    shared_examples :nested_fiber_scheduler do
      include_context FiberSchedulerSpec::Context

      let(:order) { [] }

      context "with only sync operations" do
        def operations
          FiberScheduler do
            order << 1
            FiberScheduler do
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
          FiberScheduler do
            order << 1
            sleep 0
            order << 3

            FiberScheduler do
              order << 4
              sleep 0
              order << 6
            end

            order << 5
          end
          order << 2
        end

        it "behaves async" do
          setup

          expect(order).to eq (1..6).to_a
        end
      end
    end

    context "with default setup" do
      include_examples :nested_fiber_scheduler
    end

    context "with block setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples :nested_fiber_scheduler
    end
  end
end
