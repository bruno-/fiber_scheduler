RSpec.describe FiberScheduler do
  describe "nested FiberScheduler" do
    shared_examples :nested_fiber_scheduler do
      include_context FiberSchedulerSpec::Context

      let(:order) { [] }

      context "with only sync operations" do
        let(:operations) do
          -> do
            FiberScheduler do
              order << 1
              FiberScheduler do
                order << 2
              end
              order << 3
            end
          end
        end

        it "behaves sync" do
          setup.call

          expect(order).to eq [1, 2, 3]
        end
      end

      context "with async operations" do
        let(:operations) do
          -> do
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
        end

        it "behaves async" do
          setup.call

          expect(order).to eq (1..6).to_a
        end
      end
    end

    context "with default setup" do
      include_examples :nested_fiber_scheduler
    end

    context "with block setup" do
      let(:setup) do
        -> do
          FiberScheduler do
            operations.call
          end
        end
      end

      include_examples :nested_fiber_scheduler
    end
  end
end
