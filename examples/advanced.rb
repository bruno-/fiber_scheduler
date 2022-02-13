require "httparty"
require "open-uri"
require "redis"
require "sequel"
require_relative "../lib/fiber_scheduler"

DB = Sequel.postgres
Sequel.extension(:fiber_concurrency)

FiberScheduler do
  Fiber.schedule do
    URI.open("https://httpbin.org/delay/2")
  end

  Fiber.schedule do
    HTTParty.get("https://httpbin.org/delay/2")
  end

  Fiber.schedule do
    Redis.new.blpop("abc123", 2)
  end

  Fiber.schedule do
    DB.run("SELECT pg_sleep(2)")
  end

  Fiber.schedule do
    sleep 2
  end

  Fiber.schedule do
    `sleep 2`
  end
end
