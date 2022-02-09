module FiberSchedulerSpec
  module AddressResolve
  end

  module BlockUnblock
  end

  module Context
  end
end

RSpec.shared_context FiberSchedulerSpec::Context do
  unless method_defined?(:scheduler_class)
    let(:scheduler_class) { described_class }
  end
  unless method_defined?(:scheduler)
    subject(:scheduler) { scheduler_class.new }
  end
  unless method_defined?(:setup)
    let(:setup) do
      -> do
        Fiber.set_scheduler(scheduler)

        behavior.call

        scheduler.run
      end
    end
  end

  around do |example|
    Thread.new do
      example.run
    end.join
  end
end
