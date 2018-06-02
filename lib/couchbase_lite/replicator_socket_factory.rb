require 'couchbase_lite/replicator_socket'

module CouchbaseLite
  class ReplicatorSocketFactory
    OPEN_REQUEST = lambda do |c4_socket, c4_address, _c4_slice, context|
      begin
        return if !c4_socket[:nativeHandle].null?
        uri = c4_address.to_s
        CouchbaseLite.logger.info("replicator:connect - #{uri}")
        faye_socket = Faye::WebSocket::Client.new(uri)
        factory = context.deref
        factory.sockets << ReplicatorSocket.new(faye_socket, c4_socket)
      rescue => e
        CouchbaseLite.logger.error("replicator:connect - #{e.class}: #{e.message}")
        CouchbaseLite.logger.debug(e)
      end
    end

    WRITE_REQUEST = proc do |c4_socket, c4_slice|
      begin
        CouchbaseLite.logger.debug("replicator:write - #{c4_slice[:size]} bytes")
        replication_socket = c4_socket[:nativeHandle].deref
        replication_socket.faye_socket.send(c4_slice.to_bytes)
      rescue => e
        CouchbaseLite.logger.error("replicator:write - #{e.class}: #{e.message}")
        CouchbaseLite.logger.debug(e)
      end
    end

    COMPLETED_RECEIVE_REQUEST = proc do |_c4_socket, bytes|
      CouchbaseLite.logger.debug("replicator:write_acknowledged - #{bytes} bytes")
    end

    DISPOSE_REQUEST = proc do |_c4_socket|
      CouchbaseLite.logger.debug('replicator:dispose')
    end

    REQUEST_CLOSE_REQUEST = proc do |_c4_socket|
      CouchbaseLite.logger.debug('couchbase:close')
    end

    attr_reader :c4_socket_factory, :sockets

    def initialize(server: false)
      @ref = FFI::RubyObjectRef.new
      @ref[:object_id] = object_id
      @server = server
      @c4_socket_factory = make_factory
      @sockets = []
    end

    def server?
      @server
    end

    def build(url, native_handle)
      c4_address, _ = FFI::C4Address.from_url(url)
      c4_socket = FFI.c4socket_fromNative(c4_socket_factory, native_handle, c4_address)
      c4_socket
    end

    def build_from_rack(env)
      if Faye::WebSocket.websocket?(env)
        faye_socket = Faye::WebSocket.new(env)

        url = URI::Generic.build(scheme: 'ws',
                                 host: env['REMOTE_ADDR'],
                                 port: env['SERVER_PORT'],
                                 path: env['REQUEST_PATH'])
        ws = ReplicatorSocket.new(faye_socket) { |ref| build(url, ref) }

        # Return async Rack response
        [ws, faye_socket.rack_response]
      else
        [nil, [400, 'Bad WebSocket Request']]
      end
    end

    private

    def make_factory
      factory = FFI::C4SocketFactory.new
      factory[:framing] = :kC4NoFraming
      factory[:context] = @ref
      factory[:open] = OPEN_REQUEST
      factory[:write] = WRITE_REQUEST
      factory[:completedReceive] = COMPLETED_RECEIVE_REQUEST
      factory[:requestClose] = REQUEST_CLOSE_REQUEST
      factory[:dispose] = DISPOSE_REQUEST
      factory
    end
  end
end
