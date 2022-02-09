require "fiber/scheduler"

RSpec.describe "#kernel_sleep" do
  it "" do
    expect(Fiber::Scheduler.new).to respond_to :run
    expect(Fiber::Scheduler).to respond_to :call
  end

  it "" do
    Thread.new do
      runs = 0
      start_time = Time.now

      expect_any_instance_of(Fiber::Scheduler)
        .to receive(:kernel_sleep).exactly(2).times
        .and_call_original

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
      expect(duration).to be < 0.12
      expect(runs).to eq 2
    end.join
  end

  it "" do
    Thread.new do
      runs = 0
      start_time = Time.now
      scheduler = Fiber::Scheduler.new
      Fiber.set_scheduler(scheduler)

      expect(scheduler)
        .to receive(:kernel_sleep).exactly(2).times
        .and_call_original

      Fiber.schedule do
        sleep 0.1
        runs += 1
      end

      Fiber.schedule do
        sleep 0.1
        runs += 1
      end
      scheduler.run

      duration = Time.now - start_time
      expect(duration).to be >= 0.1
      expect(duration).to be < 0.12
      expect(runs).to eq 2
    end.join
  end
end
