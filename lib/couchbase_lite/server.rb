require 'couchbase_lite/replicator'

module CouchbaseLite
  class Server
    include MonitorMixin

    attr_reader :db_resolver, :replications, :max_replications

    def initialize(db_resolver = nil, max_replications: 100, &block)
      @db_resolver = db_resolver || block
      raise ArgumentError, 'Please provide a database resolver.' unless @db_resolver
      @replications = []
      @max_replications = max_replications
      @socket_factory = ReplicatorSocketFactory.new(server: true)
      super()
    end

    def call(env)
      puts "HTTP - #{env['REQUEST_METHOD']} #{env['REQUEST_PATH']} (#{env['REMOTE_ADDR']})"
      ws, response = @socket_factory.build_from_rack(env)
      replicator = CouchbaseLite::Replicator.new(@db_resolver.call(env), socket: ws)
      register(replicator)
      replicator.start
      response
    end

    private

    def register(replication)
      synchronize do
        @replications = replications.select(&:running?)

        if @replications.size >= max_replications
          raise TooManyReplications,
                "The server cannot run more than #{max_replications} " \
                'replications at once.'
        end

        @replications << replication
      end
    end
  end
end
