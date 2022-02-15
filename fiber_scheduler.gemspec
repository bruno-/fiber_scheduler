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

  gem.add_development_dependency "async", "~> 2"
  gem.add_development_dependency "fiber_scheduler_spec"
  gem.add_development_dependency "rspec", "~> 3.11"
  gem.add_development_dependency "standard", "~> 1.7"
end
