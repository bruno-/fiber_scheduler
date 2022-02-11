require "socket"

RSpec.shared_examples FiberSchedulerSpec::AddressResolve do
  include_context FiberSchedulerSpec::Context

  context "Addrinfo.getaddrinfo" do
    let(:order) { [] }

    def operations
      Fiber.schedule do
        order << 1
        Addrinfo.getaddrinfo("example.com", 80, :AF_INET, :STREAM)
        order << 5
      end

      order << 2

      Fiber.schedule do
        order << 3
        Addrinfo.getaddrinfo("example.com", 80, :AF_INET, :STREAM)
        order << 6
      end
      order << 4
    end

    it "calls #address_resolve" do
      expect_any_instance_of(scheduler_class)
        .to receive(:address_resolve).exactly(2).times
        .and_call_original

      setup
    end

    it "behaves async" do
      setup

      expect(order).to eq (1..6).to_a
    end
  end
end

RSpec.describe FiberScheduler do
  describe "#address_resolve" do
    context "with default setup" do
      include_examples FiberSchedulerSpec::AddressResolve
    end

    context "with #call setup" do
      def setup
        FiberScheduler do
          operations
        end
      end

      include_examples FiberSchedulerSpec::AddressResolve
    end
  end
end
