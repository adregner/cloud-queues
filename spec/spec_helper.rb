require 'bundler/setup'
require 'rackspace-queues'

require 'ffaker'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end
