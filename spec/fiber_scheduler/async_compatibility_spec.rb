require "async"
require "fiber_scheduler_spec/context"

RSpec.describe FiberScheduler do
  describe "async compatibility" do
    include_context FiberSchedulerSpec::Context

    let(:order) { [] }

    context "with Async block" do
      context "without FiberScheduler options" do
        it "behaves asynchronous" do
          Async do |task|
            task.async do
              order << 1
              sleep 0.001
              order << 9
            end

            order << 2

            FiberScheduler do
              order << 3
              Fiber.schedule do
                order << 4
                sleep 0.001
                order << 10
              end

              order << 6

              Fiber.schedule do
                order << 7
                sleep 0.001
                order << 11
              end

              order << 8
              sleep 0.02
              order << 12
            end

            order << 5
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

            FiberScheduler :blocking do
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

      context "with a waiting FiberScheduler" do
        it "behaves sync" do
          Async do |task|
            order << 1

            task.async do
              order << 2
              sleep 0.01
              order << 7
            end

            order << 3

            FiberScheduler :waiting do
              order << 4

              Fiber.schedule do
                order << 5
                sleep 0.01
                order << 8
              end

              order << 6
              sleep 0.02
              order << 9
            end

            order << 10
          end

          expect(order).to eq (1..10).to_a
        end
      end

      context "with a fleeting FiberScheduler" do
        it "behaves sync" do
          Async do |task|
            order << 1

            task.async do
              order << 2
              sleep 0.01
              order << 8
            end

            order << 3

            FiberScheduler :fleeting do
              order << 4

              Fiber.schedule do
                order << 5
                sleep 0.01
                order << 9
              end

              order << 7
              sleep 5
              order << :this_line_never_runs
            end

            order << 6
          end

          expect(order).to eq (1..9).to_a
        end
      end

      context "with waiting Fiber.schedule" do
        it "waits on the fiber" do
          Async do |task|
            task.async do
              order << 1
              sleep 0.001
              order << 8
            end

            order << 2

            FiberScheduler do
              order << 3
              Fiber.schedule do
                order << 4
                sleep 0.002
                order << 9
              end

              order << 6

              Fiber.schedule(:waiting) do
                order << 7
                sleep 0.003
                order << 10
              end

              order << 11
              sleep 0.001
              order << 12
            end

            order << 5
          end

          expect(order).to eq (1..12).to_a
        end
      end

      context "with blocking Fiber.schedule" do
        it "waits on the fiber" do
          Async do |task|
            task.async do
              order << 1
              sleep 0.001
              order << 10
            end

            order << 2

            FiberScheduler do
              order << 3
              Fiber.schedule do
                order << 4
                sleep 0.002
                order << 11
              end

              order << 6

              Fiber.schedule(:blocking) do
                order << 7
                sleep 0.003
                order << 8
              end

              order << 9
              sleep 0.001
              order << 12
            end

            order << 5
          end

          expect(order).to eq (1..12).to_a
        end
      end

      context "with blocking FiberScheduler and blocking Fiber.schedule" do
        it "waits on the fiber" do
          Async do |task|
            task.async do
              order << 1
              sleep 0.001
              order << 11
            end

            order << 2

            FiberScheduler :blocking do
              order << 3
              Fiber.schedule do
                order << 4
                sleep 0.002
                order << 12
              end

              order << 5

              Fiber.schedule(:blocking) do
                order << 6
                sleep 0.003
                order << 7
              end

              order << 8
              sleep 0.001
              order << 9
            end

            order << 10
          end

          expect(order).to eq (1..12).to_a
        end
      end

      context "with fleeting Fiber.schedule" do
        context "when fleeting fiber contains a blocking operation" do
          it "never finishes" do
            Async do |task|
              task.async do
                order << 1
                sleep 0.001
                order << 9
              end

              order << 2

              FiberScheduler do
                order << 3
                Fiber.schedule do
                  order << 4
                  sleep 0.002
                  order << 11
                end

                order << 6

                Fiber.schedule(:fleeting) do
                  order << 7
                  sleep 5
                  order << :this_line_never_runs
                end

                order << 8
                sleep 0.001
                order << 10
              end

              order << 5
            end

            expect(order).to eq (1..11).to_a
          end
        end

        context "when fleeting fiber contains no blocking operations" do
          it "never finishes" do
            Async do |task|
              task.async do
                order << 1
                sleep 0.001
                order << 9
              end

              order << 2

              FiberScheduler do
                order << 3
                Fiber.schedule do
                  order << 4
                  sleep 0.002
                  order << 11
                end

                order << 6

                Fiber.schedule(:fleeting) do
                  order << 7
                end

                order << 8
                sleep 0.001
                order << 10
              end

              order << 5
            end

            expect(order).to eq (1..11).to_a
          end
        end
      end
    end

    context "with Async::Scheduler" do
      context "without FiberScheduler options" do
        it "behaves asynchronous" do
          scheduler = Async::Scheduler.new
          Fiber.set_scheduler scheduler

          Fiber.schedule do
            order << 1
            sleep 0.001
            order << 9
          end

          order << 2

          FiberScheduler do
            order << 3
            Fiber.schedule do
              order << 4
              sleep 0.001
              order << 10
            end

            order << 6

            Fiber.schedule do
              order << 7
              sleep 0.001
              order << 11
            end

            order << 8
            sleep 0.02
            order << 12
          end

          order << 5

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

          FiberScheduler :blocking do
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

      context "with a waiting FiberScheduler" do
        it "behaves sync" do
          scheduler = Async::Scheduler.new
          Fiber.set_scheduler scheduler

          order << 1

          Fiber.schedule do
            order << 2
            sleep 0.01
            order << 7
          end

          order << 3

          FiberScheduler :waiting do
            order << 4
            Fiber.schedule do
              order << 5
              sleep 0.01
              order << 8
            end

            order << 6
            sleep 0.02
            order << 9
          end

          order << 10

          scheduler.run

          expect(order).to eq (1..10).to_a
        end
      end
    end
  end
end
