require_relative "../lib/fiber_scheduler"

FiberScheduler do
  Fiber.schedule(:fleeting) do
    sleep 1000
  end

  Fiber.schedule do
    sleep 2
  end
end
