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
      log_tag = "[#{foreign_c4_socket ? 'client' : 'server'}##{object_id}]"

      faye_socket.on :open do |_event|
        CouchbaseLite.logger.debug("faye:socket_open - #{log_tag}")
        FFI.c4socket_opened(@c4_socket) if foreign_c4_socket
      end

      faye_socket.on :error do |event|
        CouchbaseLite.logger.error("faye:socket_error - #{log_tag} - #{event.inspect}")
      end

      faye_socket.on :message do |event|
        CouchbaseLite.logger.debug("faye:socket_message - #{log_tag} - #{event.data.size} bytes")
        payload = FFI::C4Slice.from_bytes(event.data)
        FFI.c4socket_received(@c4_socket, payload)
      end

      faye_socket.on :close do |event|
        CouchbaseLite.logger.debug("faye_socket_close - #{log_tag} - #{event.code} #{event.reason}")
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
