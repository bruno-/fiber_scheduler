# Fiber scheduler

Enables asynchronous programming in Ruby.

### Highlights

- Asynchronous (colorless) programming in Ruby.
- Not a framework: no DSL or new APIs. Just built-in Ruby methods:
  [Fiber.set_scheduler](https://docs.ruby-lang.org/en/master/Fiber.html#method-c-set_scheduler)
  and
  [Fiber.schedule](https://docs.ruby-lang.org/en/master/Fiber.html#method-c-schedule).
- ~400 LOC of pure Ruby, no C extensions.
- No dependencies.
- No monkey patching.

### Setup

1. With a block (recommended)
2. Set `Fiber.scheduler` directly

**With a block**

```ruby
FiberScheduler do
  # Your code here, e.g. Fiber.schedule { ... }
end
```

Recommended because:

- `Fiber.scheduler` is automatically un-set outside the block.
- This approach has full compatibility with other fiber schedulers, including
  the [async gem](https://github.com/socketry/async).

**Set Fiber.scheduler directly**

```ruby
Fiber.set_scheduler(FiberScheduler.new)

# Your code here, e.g. Fiber.schedule { ... }
```

Pros:

- Uses only built-in Ruby methods (`Fiber.set_scheduler` and `Fiber.schedule`).

Cons:

- `Fiber.scheduler` is set until the end of the current thread (unless manually
  unset).
- No compatibility when used alongside other fiber schedulers.

### Examples

#### Basic example

- Basic example running two HTTP requests in parallel:

```ruby
require "fiber_scheduler"
require "open-uri"

FiberScheduler do
  Fiber.schedule do
    URI.open("https://httpbin.org/delay/2")
  end

  Fiber.schedule do
    URI.open("https://httpbin.org/delay/2")
  end
end
```

#### Advanced example

This example runs various operations in parallel. The program total running
time is slightly more than 2 seconds, which indicates all the operations ran in
parallel.

```ruby
require "fiber_scheduler"
require "httparty"
require "open-uri"
require "redis"
require "sequel"

DB = Sequel.postgres
Sequel.extension(:fiber_concurrency)

FiberScheduler do
  Fiber.schedule do
    # This HTTP request takes 2 seconds (slightly more because of the latency)
    URI.open("https://httpbin.org/delay/2")
  end

  Fiber.schedule do
    # Use any HTTP library
    HTTParty.get("https://httpbin.org/delay/2")
  end

  Fiber.schedule do
    # Works with any TCP protocol library
    Redis.new.blpop("abc123", 2)
  end

  Fiber.schedule do
    # Make database queries
    DB.run("SELECT pg_sleep(2)")
  end

  Fiber.schedule do
    sleep 2
  end

  Fiber.schedule do
    # Run system commands
    `sleep 2`
  end
end
```

#### Scaling example

Easily run thousands and thousands of blocking operations in parallel. This
program finishes in about 2.5 seconds.

```ruby
require "fiber_scheduler"

FiberScheduler do
  10_000.times do
    Fiber.schedule do
      sleep 2
    end
  end
end
```

Gotcha: be careful about the overheads when scaling things. The below snippet
runs `sleep` which is an "inexpensive" operation. But, if we were to run
thousands of network requests there would be more overhead (establishing
TCP connections, SSL handshakes etc) which would prolong program running time.

#### Nested Fiber.schedule example

It's possible to nest `Fiber.schedule` blocks arbitrarily deep.

All the `sleep` operations in this snippet run in parallel and the program
finishes in 2 seconds total.

```ruby
require "fiber_scheduler"

FiberScheduler do
  Fiber.schedule do
    Fiber.schedule do
      sleep 2
    end

    Fiber.schedule do
      sleep 2
    end

    sleep 2
  end

  Fiber.schedule do
    sleep 2
  end
end
```

#### aiting Fiber.schedule example

Sometimes it's conventient for the parent to wait on the child fiber to
complete. Use `Fiber.schedule(waiting: true)` to achieve that.

In the below example fiber labeled `parent` will wait for the `child` fiber to
complete. Note that only the `parent` fiber waits. Other fibers run as usual.

```ruby
require "fiber_scheduler"

FiberScheduler do
  Fiber.schedule do # parent
    Fiber.schedule(waiting: true) do # child
      sleep 2
    end
    # The fiber stops here until the waiting child fiber completes.

    sleep 2
  end

  Fiber.schedule do
    sleep 2
  end
end
```

#### Blocking Fiber.schedule example

Blocking fibers "block" all the other fibers from running until they're
finished.

This program takes 4 seconds to finish.

```ruby
require "fiber_scheduler"

FiberScheduler do
  Fiber.schedule do
    Fiber.schedule(blocking: true) do
      sleep 2
    end
  end

  Fiber.schedule do
    sleep 2
  end
end
```

### Installation

```
gem install fiber_scheduler
```

Requires Ruby 3.1.

### Credits

Samuel Williams for:

- Implementing Ruby's fiber scheduler feature.
- The [default selector](lib/fiber_scheduler/selector.rb) used in this gem.

### License

[MIT](LICENSE)
