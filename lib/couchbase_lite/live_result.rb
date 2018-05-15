module CouchbaseLite
  class LiveResult
    attr_reader :first_result

    def initialize(first_result)
      @first_result = first_result
      @queue = EM::Queue.new
    end

    def push(val)
      @queue.push(val)
    end

    def on_update
      callback = proc do |result|
        yield result
        @queue.pop(&callback)
      end

      @queue.pop(&callback)
    end
  end
end
