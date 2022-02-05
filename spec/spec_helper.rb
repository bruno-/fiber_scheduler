RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    # will be the default in rspec 4
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    # will be the default in rspec 4
    mocks.verify_partial_doubles = true
  end
  # will be the default in rspec 4
  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true
  if config.files_to_run.one?
    config.default_formatter = "doc"
  end
  config.order = :random
  Kernel.srand config.seed
end
