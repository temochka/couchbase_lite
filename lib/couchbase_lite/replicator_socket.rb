module CouchbaseLite
  class ReplicatorSocket
    attr_reader :c4_socket, :faye_socket

    OPEN_REQUEST = proc do |c4_socket, c4_address, c4_slice|
      begin
        uri = URI::Generic.build(scheme: c4_address[:scheme].to_s,
                                 host: c4_address[:hostname].to_s,
                                 port: c4_address[:port],
                                 path: c4_address[:path].to_s)
        puts "couchbase:open -> #{uri.to_s}"
        faye_socket = Faye::WebSocket::Client.new(uri.to_s)
        ws = new(faye_socket, c4_socket)
        websockets << ws
        nil
      rescue => e
        puts "Unexpected error #{e.class}: #{e.message}"
      end
    end

    WRITE_REQUEST = proc do |c4_socket, c4_slice|
      begin
        puts 'couchbase:write'
        faye_socket = c4_socket[:nativeHandle].deref
        faye_socket.faye_socket.send(c4_slice.to_bytes)
      rescue => e
        puts "Unexpected error #{e.class}: #{e.message}"
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

    def self.websockets
      @websockets ||= []
    end

    def self.register
      return @factory if @factory

      Faye::WebSocket.load_adapter('thin')
      @factory = FFI::C4SocketFactory.new
      @factory[:providesWebSockets] = true
      @factory[:open] = OPEN_REQUEST
      @factory[:write] = WRITE_REQUEST
      @factory[:completedReceive] = COMPLETED_RECEIVE_REQUEST
      @factory[:close] = CLOSE_REQUEST
      @factory[:requestClose] = REQUEST_CLOSE_REQUEST
      @factory[:dispose] = DISPOSE_REQUEST
      Lantern::FFI.c4socket_registerFactory(@factory)
      true
    end

    def self.factory
      @factory
    end

    def self.register_server_socket(env)
      if Faye::WebSocket.websocket?(env)
        faye_socket = Faye::WebSocket.new(env)

        ws = new(faye_socket, nil)
        websockets << ws

        yield ws if block_given?

        # Return async Rack response
        faye_socket.rack_response
      else
        [400, 'Bad WebSocket Request']
      end
    end

    def self.close_all
      websockets.each(&:close)
    end

    def close
      return if @closed
      err = FFI::Error.new
      err[:domain] = :WebSocketDomain
      err[:code] = 0
      FFI.c4socket_closed(@c4_socket, err)
      @closed = true
    end

    private

    def initialize(faye_socket, c4_socket = nil)
      @ref = FFI::RubyObjectRef.new
      @ref[:object_id] = object_id

      @faye_socket = faye_socket
      @c4_socket = c4_socket ||
                   begin
                     env = faye_socket.env
                     url = URI::Generic.build(scheme: 'ws',
                                              host: env['REMOTE_ADDR'],
                                              port: env['SERVER_PORT'],
                                              path: env['REQUEST_PATH'])
                     c4_address, _ = FFI::C4Address.from_url(url)
                     FFI.c4socket_fromNative(self.class.factory,
                                             @ref,
                                             c4_address)
                   end

      @c4_socket[:nativeHandle] = @ref

      faye_socket.on :open do |event|
        puts 'faye_socket:open -> c4socket_opened'
        FFI.c4socket_opened(@c4_socket) if c4_socket
      end

      faye_socket.on :error do |event|
        puts 'faye_socket:error -> *stub*'
      end

      faye_socket.on :message do |event|
        puts 'faye_socket:message -> c4socket_receive'
        FFI.c4socket_received(@c4_socket, FFI::C4Slice.from_bytes(event.data))
      end

      faye_socket.on :close do |event|
        puts 'faye_socket:close -> *stub*'
        # puts [:close, event.code, event.reason]
      end
    end
  end
end
