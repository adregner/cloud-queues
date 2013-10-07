require 'bundler/setup'
require 'simplecov'
SimpleCov.start
require 'cloud-queues'

require 'ffaker'

Dir["./spec/**/examples_*.rb"].sort.each {|f| require f}

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  #config.filter_run_excluding :slow => true
end
