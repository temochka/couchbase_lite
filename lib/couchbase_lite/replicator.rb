require 'couchbase_lite/replicator_socket_factory'

module CouchbaseLite
  class Replicator
    include ErrorHandling

    DOCUMENT_ERROR_CALLBACK = lambda do |_replicator, pushing, docID, _error, _transient, _context|
      CouchbaseLite.logger.error("replicator:document_error - #{docID.to_s}, pushing: #{pushing.inspect}")
    end

    class Status
      attr_reader :c4_status

      def initialize(c4_status)
        @c4_status = c4_status
      end

      def level
        case @c4_status[:level]
        when :kC4Stopped
          :stopped
        when :kC4Offline
          :offline
        when :kC4Connecting
          :connecting
        when :kC4Idle
          :idle
        when :kC4Busy
          :busy
        end
      end

      def progress
        progress = @c4_status[:progress]
        OpenStruct.new(units_completed: progress[:unitsCompleted],
                       units_total: progress[:unitsTotal],
                       document_count: progress[:documentCount])
      end

      def error
        @c4_status[:error] && LibraryError.for(@c4_status[:error])
      end

      def to_h
        {
          level: level,
          progress: progress.to_h,
          error: error.to_s
        }
      end
    end

    attr_accessor :socket

    def initialize(database, socket_factory: nil, url: nil, socket: nil)
      raise ArgumentError, 'Both url and socket cannot be nil.' if url.nil? && socket.nil?
      raise ArgumentError, 'Please provide a socket factory when url is specified.' if url && !socket_factory
      @database = database
      @url = url
      @socket = socket
      @running = false
      @is_server = !!socket
      @socket_factory = socket_factory
    end

    def start
      c4_repl = if server?
                  CouchbaseLite.logger.info('replicator:start_server')
                  null_err do |e|
                    FFI.c4repl_newWithSocket(@database.c4_database, @socket.c4_socket, parameters(true), e)
                  end
                else
                  CouchbaseLite.logger.info('replicator:start_client')
                  address, dbname = FFI::C4Address.from_url(@url)

                  null_err do |e|
                    FFI.c4repl_new(@database.c4_database, address, dbname, nil, parameters, e)
                  end
                end

      @c4_repl = FFI::C4Replicator.auto(c4_repl)
      @running = true
    end

    def server?
      @is_server
    end

    def stop
      FFI.c4repl_stop(c4_repl) if c4_repl
      @running = false
    end

    def running?
      @running
    end

    def status
      return unless @c4_repl

      Status.new(FFI.c4repl_getStatus(@c4_repl))
    end

    private

    attr_reader :c4_repl

    def parameters(server = false)
      p = FFI::C4ReplicatorParameters.new
      p[:push] = server ? :kC4Passive : :kC4Continuous
      p[:pull] = server ? :kC4Passive : :kC4Continuous
      p[:onDocumentError] = DOCUMENT_ERROR_CALLBACK
      p[:socketFactory] = @socket_factory&.c4_socket_factory
      p
    end
  end
end
