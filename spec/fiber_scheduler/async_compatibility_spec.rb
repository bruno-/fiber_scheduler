require "async"

RSpec.describe FiberScheduler do
  describe "async compatibility" do
    include_context FiberSchedulerSpec::Context

    let(:order) { [] }

    context "with Async block" do
      context "without FiberScheduler options" do
        it "behaves synchronous" do
          Async do |task|
            task.async do
              order << 1
              sleep 0.001
              order << 8
            end

            order << 2

            FiberScheduler do # default 'wait: true' option
              order << 3
              Fiber.schedule do
                order << 4
                sleep 0.001
                order << 9
              end

              order << 5

              Fiber.schedule do
                order << 6
                sleep 0.001
                order << 10
              end

              order << 7
              sleep 0.02
              order << 11
            end

            order << 12
          end

          expect(order).to eq (1..12).to_a
        end
      end

      context "with a blocking FiberScheduler" do
        it "blocks all other async tasks" do
          Async do |task|
            order << 1

            task.async do
              order << 2
              sleep 0.01
              order << 8
            end

            order << 3

            FiberScheduler(blocking: true) do
              order << 4
              Fiber.schedule do
                order << 5
                sleep 0.01
                order << 9
              end
              sleep 0.02
              order << 6
            end

            order << 7
          end

          expect(order).to eq (1..9).to_a
        end
      end

      context "with a non-waiting FiberScheduler" do
        it "behaves async" do
          Async do |task|
            order << 1

            task.async do
              order << 2
              sleep 0.01
              order << 8
            end

            order << 3

            FiberScheduler(wait: false) do
              order << 4
              Fiber.schedule do
                order << 5
                sleep 0.01
                order << 9
              end
              order << 7
              sleep 0.02
              order << 10
            end

            order << 6
          end

          expect(order).to eq (1..10).to_a
        end
      end
    end

    context "with Async::Scheduler" do
      context "without FiberScheduler options" do
        it "behaves synchronous" do
          scheduler = Async::Scheduler.new
          Fiber.set_scheduler scheduler

          Fiber.schedule do
            order << 1
            sleep 0.001
            order << 8
          end

          order << 2

          FiberScheduler do # default 'wait: true' option
            order << 3
            Fiber.schedule do
              order << 4
              sleep 0.001
              order << 9
            end

            order << 5

            Fiber.schedule do
              order << 6
              sleep 0.001
              order << 10
            end

            order << 7
            sleep 0.02
            order << 11
          end

          order << 12

          scheduler.run

          order << 13

          expect(order).to eq (1..13).to_a
        end
      end

      context "with a blocking FiberScheduler" do
        it "blocks all other async tasks" do
          scheduler = Async::Scheduler.new
          Fiber.set_scheduler scheduler

          order << 1

          Fiber.schedule do
            order << 2
            sleep 0.01
            order << 8
          end

          order << 3

          FiberScheduler(blocking: true) do
            order << 4
            Fiber.schedule do
              order << 5
              sleep 0.01
              order << 9
            end
            sleep 0.02
            order << 7
          end

          order << 6

          scheduler.run

          expect(order).to eq (1..9).to_a
        end
      end

      context "with a non-waiting FiberScheduler" do
        it "behaves async" do
          scheduler = Async::Scheduler.new
          Fiber.set_scheduler scheduler

          order << 1

          Fiber.schedule do
            order << 2
            sleep 0.01
            order << 8
          end

          order << 3

          FiberScheduler(wait: false) do
            order << 4
            Fiber.schedule do
              order << 5
              sleep 0.01
              order << 9
            end
            order << 7
            sleep 0.02
            order << 10
          end

          order << 6

          scheduler.run

          expect(order).to eq (1..10).to_a
        end
      end
    end
  end
end
