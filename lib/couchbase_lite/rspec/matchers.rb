require 'rspec/expectations'
require 'pp'

RSpec::Matchers.define :select_records do |expected|
  diffable

  match do |query|
    @actual = query.run(@arguments || {}).to_a
    expected == @actual
  end

  chain :with_arguments do |arguments|
    @arguments = arguments
  end
end
