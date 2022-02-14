require "async"
require "benchmark"
require_relative "../lib/fiber_scheduler"

Benchmark.bmbm do |x|
  # Max thread count is often 2048
  iterations = 2_000

  x.report("Async") do
    Async do |task|
      iterations.times do
        task.async { sleep 0 }
      end
    end
  end

  x.report("Thread.new") do
    iterations.times.map {
      Thread.new { sleep 0 }
    }.each(&:join)
  end

  FiberScheduler do
    x.report("FiberScheduler") do
      FiberScheduler do
        iterations.times do
          Fiber.schedule { sleep 0 }
        end
      end
    end
  end
end

# Rehearsal --------------------------------------------------
# Async            0.087607   0.042180   0.129787 (  0.262384)
# Thread.new       0.046044   0.206628   0.252672 (  0.148690)
# FiberScheduler   0.057139   0.017577   0.074716 (  0.078964)
# ----------------------------------------- total: 0.457175sec
#
#                      user     system      total        real
# Async            0.062762   0.008537   0.071299 (  0.097750)
# Thread.new       0.035221   0.189419   0.224640 (  0.126426)
# FiberScheduler   0.020268   0.000317   0.020585 (  0.020838)
