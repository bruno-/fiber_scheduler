require "fiber_scheduler_spec/context"

RSpec.describe FiberScheduler do
  describe "nested FiberScheduler" do
    shared_examples :nested_fiber_scheduler do
      include_context FiberSchedulerSpec::Context

      let(:order) { [] }

      context "with default arguments" do
        context "with no non-blocking operations" do
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

          it "behaves asynchronous" do
            setup

            expect(order).to eq (1..6).to_a
          end
        end
      end

      context "with :waiting arg" do
        context "with non-blocking operations" do
          def operations
            FiberScheduler :waiting do
              order << 1
              sleep 0
              order << 2
            end
            order << 3
          end

          it "behaves sync" do
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
