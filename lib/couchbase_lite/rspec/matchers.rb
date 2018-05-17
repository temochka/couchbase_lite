require 'rspec/expectations'
require 'pp'

RSpec::Matchers.define :select_records do |expected|
  match do |query|
    @actual = query.run.to_a
    expected == @actual
  end

  diffable
end
