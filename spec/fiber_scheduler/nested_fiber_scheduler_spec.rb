require "fiber_scheduler_spec/context"

RSpec.describe FiberScheduler do
  describe "nested FiberScheduler" do
    shared_examples :nested_fiber_scheduler do
      include_context FiberSchedulerSpec::Context

      let(:order) { [] }

      context "with default arguments" do
        context "with only blocking operations" do
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

        context "with non-blocking operations" do
          def operations
            FiberScheduler do
              order << 1
              sleep 0
              order << 2

              FiberScheduler do
                order << 3
                sleep 0
                order << 4
              end

              order << 5
            end
            order << 6
          end

          it "behaves synchronous" do
            setup

            expect(order).to eq (1..6).to_a
          end
        end
      end

      context "with 'waiting: false' option" do
        context "with async operations" do
          def operations
            FiberScheduler(waiting: false) do
              order << 1
              sleep 0
              order << 3
            end
            order << 2
          end

          it "behaves async" do
            setup

            expect(order).to eq (1..3).to_a
          end
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
