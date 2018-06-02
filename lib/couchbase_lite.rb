require 'ffi'
require 'json'
require 'logger'
require 'observer'

module CouchbaseLite
  class Error < StandardError; end

  class ReplicationError < Error; end
  class TooManyReplications < ReplicationError; end

  class LibraryError < Error
    attr_reader :c4_error

    def self.for(c4_error)
      error_class = case [c4_error.domain, c4_error.code]
                    when [:LiteCoreDomain, 7]
                      DocumentNotFound
                    else
                      self
                    end
      error_class.new(c4_error, FFI.c4error_getMessage(c4_error))
    end

    def initialize(c4_error, message)
      @c4_error = c4_error
      super("#{c4_error.domain}(#{c4_error.code}): #{message}")
    end
  end

  class DocumentNotFound < LibraryError; end

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
      c4_error = FFI::C4Error.new
      result = yield(c4_error)
      raise LibraryError.for(c4_error) if err?(result, reason)
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

  module Conversions
    def json(val)
      if val.is_a?(String)
        val
      else
        val.to_json
      end
    end
  end

  class << self
    def logger
      @logger ||= Logger.new(STDOUT, level: Logger::ERROR)
    end
    attr_writer :logger
  end
end

require 'couchbase_lite/database'
require 'couchbase_lite/document'
require 'couchbase_lite/ffi'
require 'couchbase_lite/live_result'
require 'couchbase_lite/query'
require 'couchbase_lite/query_result'
require 'couchbase_lite/version'

if defined?($COUCHBASE_LITE_DEBUG) && $COUCHBASE_LITE_DEBUG
  CouchbaseLite.logger.level = Logger::DEBUG
else
  CouchbaseLite::FFI::C4LogDomain.all.each do |domain|
    CouchbaseLite::FFI.c4log_setLevel(domain, :kC4LogNone)
  end
end
