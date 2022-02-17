# Fiber scheduler

Ruby 3 has
[fiber scheduler hooks](https://docs.ruby-lang.org/en/master/Fiber/SchedulerInterface.html)
that enable asynchronous programming. In order to make this work you need a
"fiber scheduler class", **but Ruby does not provide a default one**.

This gem aims to fill that void by providing a fiber scheduler class that makes
a great default. It's easy to use, performant, and can be used with
**just built-in Ruby methods**.

`fiber_scheduler`'s killer feature 💣 is full compatibility with any other
"fiber scheduler implementation", including the
[async gem](https://github.com/socketry/async). Write code using
`fiber_scheduler` and it works seamlessly with `async`, `bsync` or whatever
other `_sync` gem comes in the future.

### Installation

```
gem install fiber_scheduler
```

Requires Ruby 3.1.

### Highlights

- Enables asynchronous (colorless) programming in Ruby.
- Killer feature: full compatibility with any other "fiber scheduler class",
  including the [async gem](https://github.com/socketry/async).
- Not a framework: no DSL or new APIs. Can be used with just built-in Ruby
  methods:
  [Fiber.set_scheduler](https://docs.ruby-lang.org/en/master/Fiber.html#method-c-set_scheduler)
  and
  [Fiber.schedule](https://docs.ruby-lang.org/en/master/Fiber.html#method-c-schedule).
- ~500 LOC of pure Ruby, no C extensions.
- No dependencies.

### Setup

1. With a block (recommended)
2. Set `Fiber.scheduler` directly

**With a block (recommended)**

```ruby
FiberScheduler do
  # Your code here, e.g. Fiber.schedule { ... }
end
```

Recommended because:

- This approach has
  [full compatibility with any other fiber scheduler](https://github.com/bruno-/fiber_scheduler#compatibility-with-other-fiber-schedulers).
- `Fiber.scheduler` is automatically un-set outside the block.

**Set Fiber.scheduler directly**

```ruby
Fiber.set_scheduler(FiberScheduler.new)

# Your code here, e.g. Fiber.schedule { ... }
```

`Fiber.scheduler` is set until the end of the current thread, unless manually
unset with `Fiber.set_scheduler(nil)`.

Pros:

- Uses only built-in Ruby methods `Fiber.set_scheduler` and `Fiber.schedule`.

Cons:

- No compatibility with other fiber schedulers.

### Examples

#### Basic example

Basic example running two HTTP requests in parallel:

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

This example runs various operations in parallel. The example total running
time is slightly more than 2 seconds, which indicates all the operations ran in
parallel.

Note that all the operations used in `Fiber.schedule` blocks below are either
common gems or built-in Ruby methods. They all work asynchronously with this
library, no monkey patching!

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

#### Waiting Fiber.schedule example

Sometimes it's conventient for the parent to wait on the child fiber to
complete. Use `Fiber.schedule(:waiting)` to achieve that.

In the below example fiber labeled `parent` will wait for the `child` fiber to
complete. Note that only the `parent` fiber waits, other fibers run as usual.

This example takes 4 seconds to finish.

```ruby
require "fiber_scheduler"

FiberScheduler do
  Fiber.schedule do # parent
    Fiber.schedule(:waiting) do # child
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

This example takes 4 seconds to finish.

```ruby
require "fiber_scheduler"

FiberScheduler do
  Fiber.schedule do
    Fiber.schedule(:blocking) do
      sleep 2
    end
  end

  Fiber.schedule do
    sleep 2
  end
end
```

#### Volatile Fiber.schedule example

Volatile fibers end when all the "durable" fibers finish.
Volatile fibers (by design) may not complete all their work.

This is useful if you have a neverending task that performs some
cleanup work that should finish when the rest of the program completes.

This example takes 2 seconds to finish.

```ruby
require "fiber_scheduler"

FiberScheduler do
  Fiber.schedule(:volatile) do
    # This fiber will live for only 2 seconds.

    loop do
      cleanup_work # this method will run only once

      sleep 10
    end
  end

  Fiber.schedule do
    sleep 2
  end
end
```

### Compatibility with other fiber schedulers

#### [async gem](https://github.com/socketry/async)

`async` is an awesome asynchronous programming library, if not a framework.
If `async` is like Rails, then `fiber_scheduler` is plain Ruby.

`fiber_scheduler` is fully compatible with `async`:

```ruby
Async do |task|
  task.async do
    # code ...
  end

  FiberScheduler do
    Fiber.schedule do
      # code ...
    end
  end

  # ...
end
```

Note that currently the opposite doesn't work:

```ruby
FiberScheduler do
  Async do
    # ...
  end

  Fiber.schedule do # No scheduler is available! (RuntimeError)
    # ...
  end
end
```

#### Other fiber scheduler implementations

`fiber_scheduler` gem works with any other fiber scheduler class (current and
future ones). Example:

```ruby
Fiber.set_scheduler(AnotherScheduler.new)

# stuff

FiberScheduler do
  # works just fine
end

# more stuff
```

`fiber_scheduler` is like choosing pure Ruby: it's a safe choice because you
know it works and will continue working with everything else in Ruby's
asynchronous eco-system.

### Performance

This [basic perf benchmark](examples/performance.rb) looks promising.

HINT: make sure to install `io-event` gem alongside `fiber_scheduler` for a
performance improvement.

### Credits

Samuel Williams for:

- Implementing Ruby's fiber scheduler feature.
- The [default selector](lib/fiber_scheduler/selector.rb) used in this gem.

### License

[MIT](LICENSE)
