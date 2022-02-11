RSpec.describe FiberScheduler::Triggers do
  subject(:triggers) { described_class.new }

  describe "#call" do
    let(:order) { [] }

    context "with empty triggers" do
      it "does nothing" do
        expect(order).to be_empty
      end
    end

    context "with triggers added randomly" do
      let(:indices) { (-10..10).to_a }

      before do
        indices.shuffle.each do |index|
          triggers.add(index.fdiv(100)) { order << index }
        end
      end

      it "runs triggers in order" do
        sleep 0.11
        triggers.call

        expect(order).to eq indices
      end
    end

    context "when triggers are disabled" do
      let(:indices) { (-10..10).to_a }

      before do
        indices.each do |index|
          trigger = triggers.add(index.fdiv(100)) { order << index }
          trigger.disable if (index % 2).zero? # disable even index triggers
        end
      end

      it "does not run disabled triggers" do
        sleep 0.11
        triggers.call

        expect(order).to eq (-9.step(9, 2)).to_a
      end
    end
  end
end
