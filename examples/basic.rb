require "open-uri"
require_relative "../lib/fiber_scheduler"

FiberScheduler do
  Fiber.schedule do
    URI.open("https://httpbin.org/delay/2")
  end

  Fiber.schedule do
    URI.open("https://httpbin.org/delay/2")
  end
end
