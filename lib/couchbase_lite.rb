require 'ffi'
require 'json'

module CouchbaseLite
  class Error < StandardError; end

  module ErrorHandling
    private

    def null_err(&block)
      err(:null, &block)
    end

    def false_err(&block)
      err(:false, &block)
    end

    def zero_err(&block)
      err(:zero, &block)
    end

    def blank_err(&block)
      err(:blank, &block)
    end

    def err(reason)
      error = FFI::C4Error.new
      result = yield(error)
      raise Error, FFI.c4error_getMessage(error) if err?(result, reason)
      result
    end

    def err?(result, reason)
      case reason
      when :null
        result.to_ptr.null?
      when :false
        !result
      when :zero
        result.zero?
      when :blank
        result[:buf].null?
      else
        raise ArgumentError, "Unknown error mode #{reason}"
      end
    end
  end
end

require 'couchbase_lite/database'
require 'couchbase_lite/document'
require 'couchbase_lite/ffi'
require 'couchbase_lite/live_result'
require 'couchbase_lite/query'
require 'couchbase_lite/query_result'
require 'couchbase_lite/replicator'
require 'couchbase_lite/replicator_socket'
require 'couchbase_lite/version'
