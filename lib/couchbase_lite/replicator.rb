module CouchbaseLite
  class Replicator
    include ErrorHandling

    def initialize(database, url: nil, socket: nil)
      raise ArgumentError, 'Both url and socket cannot be nil.' if url.nil? && socket.nil?
      @database = database
      @socket = socket
    end

    def start
      c4_repl = if @socket
                  puts 'Creating a replicator for an open socket'
                  null_err do |e|
                    FFI.c4repl_newWithSocket(database.c4_database, @socket.c4_socket, parameters(true), e)
                  end
                else
                  puts 'Creating a new replicator'
                  address, dbname = FFI::C4Address.from_url(url)

                  null_err do |e|
                    FFI.c4repl_new(database.c4_database, address, dbname, nil, parameters, e)
                  end
                end

      @c4_repl = FFI::C4Replicator.auto(c4_repl)
    end

    def stop
      @socket&.close
      FFI.c4repl_stop(c4_repl) if c4_repl
    end

    private

    attr_reader :c4_repl

    def parameters(server = false)
      p = FFI::C4ReplicatorParameters.new
      p[:push] = server ? :kC4Passive : :kC4Continuous
      p[:pull] = server ? :kC4Passive : :kC4Continuous
      p
    end
  end
end
