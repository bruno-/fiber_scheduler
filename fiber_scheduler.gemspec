require_relative "lib/fiber_scheduler/version"

Gem::Specification.new do |gem|
  gem.name = "fiber_scheduler"
  gem.version = FiberScheduler::VERSION
  gem.summary = "Fiber scheduler"
  gem.author = "Bruno Sutic"
  gem.email = "code@brunosutic.com"
  gem.require_paths = %w[lib]
  gem.files = Dir["lib/**/*"]
  gem.required_ruby_version = ">= 3.1.0"
  gem.homepage = "https://github.com/bruno-/fiber_scheduler"
  gem.license = "MIT"

  gem.add_dependency "io-event", "~> 1.0"
  gem.add_dependency "timers", "~> 4.3"

  gem.add_development_dependency "rspec", "~> 3.11"
  gem.add_development_dependency "rubocop-rspec", "~> 2.8"
  gem.add_development_dependency "standard", "~> 1.7"
end