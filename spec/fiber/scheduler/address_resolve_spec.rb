require "fiber/scheduler"
require "socket"

RSpec.describe "#address_resolve" do
  context "Addrinfo.getaddrinfo" do
    it "" do
      Thread.new do
        order = []

        Fiber::Scheduler.call do
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
        order << 7

        expect(order).to eq (1..7).to_a
      end.join
    end
  end
end
