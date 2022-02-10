RSpec.describe FiberScheduler::Timers do
  subject(:timers) { described_class.new }

  describe "#call" do
    let(:order) { [] }

    context "with empty timers" do
      it "does nothing" do
        expect(order).to be_empty
      end
    end

    context "with timers added randomly" do
      let(:indices) { (-10..10).to_a }

      before do
        indices.shuffle.each do |index|
          timers.add(index.fdiv(100)) { order << index }
        end
      end

      it "runs timers in order" do
        sleep 0.11
        timers.call

        expect(order).to eq indices
      end
    end
  end
end
