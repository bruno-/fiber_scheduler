require "fiber_scheduler_spec"

RSpec.describe FiberScheduler do
  context "with default setup" do
    include_examples FiberSchedulerSpec
  end

  context "with block setup" do
    def setup
      FiberScheduler do
        operations
      end
    end

    include_examples FiberSchedulerSpec
  end
end
