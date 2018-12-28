module CouchbaseLite
  class LiveResult
    attr_reader :database, :result, :callback

    def initialize(database, first_result, &block)
      @result = first_result
      @database = database
      @callback = block
      database.add_observer(self, :update)
      fire
    end

    def destroy
      database.delete_observer(self)
    end

    def update(event, *_args)
      return unless event == :commit

      refreshed = @result.refresh
      return if refreshed == @result

      @result = refreshed
      fire
    end

    private

    def fire
      callback.call(@result) if callback
    end
  end
end
