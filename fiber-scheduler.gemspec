# rubocop:disable Security/Eval
gem = eval(File.read("fiber_scheduler.gemspec"), nil, "fiber_scheduler.gemspec")
gem.name = "fiber-scheduler"
gem
# rubocop:enable Security/Eval
