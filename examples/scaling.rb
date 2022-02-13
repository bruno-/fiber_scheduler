require_relative "../lib/fiber_scheduler"

FiberScheduler do
  10_000.times do
    Fiber.schedule do
      sleep 2
    end
  end
end
