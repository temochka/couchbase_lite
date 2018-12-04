require 'bundler/setup'

$COUCHBASE_LITE_DEBUG = true if ENV['COUCHBASE_LITE_DEBUG'] == '1'

# It is important to load eventmachine before couchbase_lite or Ruby will crash on Linux
# The reason is that eventmachine links against libstdc++, while libCoreLite needs libc++.
# Experimentally, I’ve found that loading libc++ later seems to work around the crash.
# See https://github.com/temochka/embug-1203 for more details
require 'eventmachine'
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
