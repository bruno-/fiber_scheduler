RSpec.xdescribe FiberScheduler::Timeouts do
  subject(:timeouts) { described_class.new }

  describe "#call" do
    let(:order) { [] }

    context "with empty timeouts" do
      it "does nothing" do
        expect(order).to be_empty
      end
    end

    context "with timeouts added randomly" do
      let(:indices) { (-10..10).to_a }

      before do
        indices.shuffle.each do |index|
          timeouts.add(index.fdiv(100)) { order << index }
        end
      end

      it "runs timeouts in order" do
        sleep 0.11
        timeouts.call

        expect(order).to eq indices
      end
    end

    context "when timeouts are disabled" do
      let(:indices) { (-10..10).to_a }

      before do
        indices.each do |index|
          timeout = timeouts.add(index.fdiv(100)) { order << index }
          timeout.disable if (index % 2).zero? # disable even index timeouts
        end
      end

      it "does not run disabled timeouts" do
        sleep 0.11
        timeouts.call

        expect(order).to eq (-9.step(9, 2)).to_a
      end
    end
  end
end
