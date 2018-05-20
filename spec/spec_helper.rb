require 'bundler/setup'

$COUCHBASE_LITE_DEBUG = true if ENV['COUCHBASE_LITE_DEBUG'] == '1'

require 'couchbase_lite'
require 'couchbase_lite/rspec/contexts'
require 'couchbase_lite/rspec/matchers'
require 'irb'
require 'n1ql'
require 'securerandom'
require 'tmpdir'
require 'support/helpers'

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.include Helpers

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
