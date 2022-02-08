require "fiber/scheduler"

RSpec.describe "#kernel_sleep" do
  it "" do
    expect(Fiber::Scheduler.new).to respond_to :run
    expect(Fiber::Scheduler).to respond_to :call
  end

  it "" do
    runs = 0
    start_time = Time.now
    Fiber::Scheduler.call do
      Fiber.schedule do
        sleep 0.1
        runs += 1
      end

      Fiber.schedule do
        sleep 0.1
        runs += 1
      end
    end

    duration = Time.now - start_time
    expect(duration).to be >= 0.1
    expect(duration).to be < 0.11
    expect(runs).to eq 2
  end

  it "" do
    runs = 0
    start_time = Time.now
    scheduler = Fiber::Scheduler.new
    Fiber.set_scheduler(scheduler)

    Fiber.schedule do
      sleep 0.1
      runs += 1
    end

    Fiber.schedule do
      sleep 0.1
      runs += 1
    end
    scheduler.run

    expect(Time.now - start_time).to be_within(0.01).of(0.1)
    expect(runs).to eq 2
  end
end
