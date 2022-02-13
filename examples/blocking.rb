require_relative "../lib/fiber_scheduler"

FiberScheduler do
  Fiber.schedule do
    Fiber.schedule(blocking: true) do
      sleep 2
    end
  end

  Fiber.schedule do
    sleep 2
  end
end
