require 'couchbase_lite/replicator_socket'

module CouchbaseLite
  class ReplicatorSocketFactory
    OPEN_REQUEST = proc do |c4_socket, c4_address, _c4_slice, context|
      begin
        puts "couchbase:open -> #{c4_address.to_s}"
        uri = URI::Generic.build(scheme: c4_address[:scheme].to_s,
                                 host: c4_address[:hostname].to_s,
                                 port: c4_address[:port],
                                 path: c4_address[:path].to_s)
        faye_socket = Faye::WebSocket::Client.new(uri.to_s)
        factory = context.deref
        factory.sockets << ReplicatorSocket.new(faye_socket, c4_socket)
        nil
      rescue => e
        puts "Unexpected error #{e.class}: #{e.message}"
      end
    end

    WRITE_REQUEST = proc do |c4_socket, c4_slice|
      begin
        puts "couchbase:write (#{c4_slice.to_s}, size: #{c4_slice[:size]})"
        replication_socket = c4_socket[:nativeHandle].deref
        replication_socket.faye_socket.send(c4_slice.to_bytes)
      rescue => e
        puts "Unexpected error #{e.class}: #{e.message}"
        puts "#{e.backtrace.join("\n")}"
      end
    end

    COMPLETED_RECEIVE_REQUEST = proc do |c4_socket, bytes|
      puts "couchbase:received (#{bytes} bytes)"
    end

    DISPOSE_REQUEST = proc do |c4_socket|
      puts 'cochbase:dispose'
    end

    CLOSE_REQUEST = proc do |c4_socket|
      puts 'couchbase:close'
    end

    REQUEST_CLOSE_REQUEST = proc do |c4_socket|
      puts 'couchbase:request_close'
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
        host = env['REMOTE_ADDR'] == '::1' ? 'localhost' : env['REMOTE_ADDR']

        url = URI::Generic.build(scheme: 'ws',
                                 host: host,
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
      factory[:close] = CLOSE_REQUEST
      factory[:requestClose] = REQUEST_CLOSE_REQUEST
      factory[:dispose] = DISPOSE_REQUEST
      factory
    end
  end
end
