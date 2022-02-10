require "async"

RSpec.describe FiberScheduler do
  describe "async compatibility" do
    include_context FiberSchedulerSpec::Context

    let(:order) { [] }

    it "behaves async" do
      Async do |task|
        order << 1
        FiberScheduler do
          order << 2
          sleep 0.01
          order << 6
        end

        order << 3

        task.async do
          order << 4
          sleep 0.02
          order << 7
        end
        order << 5
      end

      expect(order).to eq (1..7).to_a
    end
  end
end
