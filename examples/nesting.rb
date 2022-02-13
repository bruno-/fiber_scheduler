require_relative "../lib/fiber_scheduler"

FiberScheduler do
  Fiber.schedule do
    Fiber.schedule do
      sleep 2
    end

    Fiber.schedule do
      sleep 2
    end

    sleep 2
  end

  Fiber.schedule do
    sleep 2
  end
end
