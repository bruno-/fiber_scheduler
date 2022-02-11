module FiberSchedulerSpec
  module AddressResolve
  end

  module BlockUnblock
  end

  module Context
  end

  module Close
  end

  module Fiber
  end

  module SocketIO
  end

  module TimeoutAfter
  end

  module IOWait
  end

  module KernelSleep
  end

  module ProcessWait
  end
end

RSpec.shared_context FiberSchedulerSpec::Context do
  unless method_defined?(:scheduler_class)
    let(:scheduler_class) { described_class }
  end
  unless method_defined?(:scheduler)
    subject(:scheduler) { scheduler_class.new }
  end
  def setup
    ::Fiber.set_scheduler(scheduler)

    operations

    scheduler.run
  end

  around do |example|
    result = Thread.new do
      example.run
    end.join(1)

    expect(result).to be_a Thread # failure means spec timed out
  end
end
