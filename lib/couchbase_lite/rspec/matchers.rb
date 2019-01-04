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

RSpec::Matchers.define :run_until do |_|
  match do |block|
    raise 'Event machine is not running.' unless EventMachine.reactor_running?

    begin
      block.call
    rescue => e
      EM.stop
      raise e
    end

    EventMachine.tick_loop do
      if block_arg.call || timeout?
        begin
          @and_then.call if @and_then
          :stop
        rescue
          :stop
        ensure
          @always.call if @always
        end
      end
    end
    true
  end

  supports_block_expectations

  def timeout?
    @timeout && Time.now.to_i >= @timeout
  end

  chain :with_timeout do |timeout|
    @timeout = Time.now.to_i + timeout
  end

  chain :and_then do |&block|
    @and_then = block
  end

  chain :always do |&block|
    @always = block
  end
end

RSpec::Matchers.define :have_side_effect do |_|
  match do |block|
    block.call
    loop do
      break if block_arg.call || timeout?
      sleep 0.01
    end
    true
  end

  supports_block_expectations

  def timeout?
    @timeout && Time.now.to_i >= @timeout
  end

  chain :with_timeout do |timeout|
    @timeout = Time.now.to_i + timeout
  end
end
