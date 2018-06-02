require 'faye/websocket'

Faye::WebSocket.load_adapter('thin')

module CouchbaseLite
  class ReplicatorSocket
    attr_reader :c4_socket, :faye_socket

    def initialize(faye_socket, foreign_c4_socket = nil)
      raise ArgumentError, 'Please provide a C4Socket or a block.' unless foreign_c4_socket || block_given?

      @ref = FFI::RubyObjectRef.new
      @ref[:object_id] = object_id

      @faye_socket = faye_socket
      @c4_socket = foreign_c4_socket || (yield @ref)
      @c4_socket[:nativeHandle] = @ref
      @node = foreign_c4_socket ? 'client' : 'server'

      faye_socket.on :open do |event|
        puts "#{@node}:faye_socket:open -> c4socket_opened(#{object_id})"
        FFI.c4socket_opened(@c4_socket) if foreign_c4_socket
      end

      faye_socket.on :error do |event|
        puts "#{@node}:faye_socket:error -> *stub*"
        puts "error: #{event.inspect}"
      end

      faye_socket.on :message do |event|
        puts "#{@node}:faye_socket:message -> c4socket_receive"
        payload = FFI::C4Slice.from_bytes(event.data)
        puts "#{@node}:received: #{payload} (size: #{payload[:size]})"
        FFI.c4socket_received(@c4_socket, payload)
      end

      faye_socket.on :close do |event|
        puts 'faye_socket:close -> *stub*'
        # puts [:close, event.code, event.reason]
      end
    end

    def close
      return if @closed
      err = FFI::Error.new
      err[:domain] = :WebSocketDomain
      err[:code] = 0
      FFI.c4socket_closed(@c4_socket, err)
      @closed = true
    end
  end
end
