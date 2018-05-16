require 'bundler/setup'
require 'couchbase_lite'
require 'irb'
require 'securerandom'
require 'tmpdir'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
