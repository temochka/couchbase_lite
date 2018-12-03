module CouchbaseLite
  class BlobStorage
    include ErrorHandling

    attr_accessor :database

    def initialize(database)
      @c4_blob_storage = false_err do |e|
        FFI.c4db_getBlobStore(database.c4_database, e)
      end
    end

    def read(digest:, **_)
      blank_err do |e|
        FFI.c4blob_getContents(@c4_blob_storage, FFI::C4BlobKey.from_string(digest), e)
      end.to_s
    end

    def open(_key)
      raise NotImplementedError, 'Not implemented.'
    end

    def store(contents, content_type: nil)
      digest = FFI::C4BlobKey.new

      false_err do |e|
        FFI.c4blob_create(@c4_blob_storage, FFI::C4String.from_string(contents), nil, digest, e)
      end

      {
        '@type': 'blob',
        digest: digest.to_s,
        content_type: content_type,
        length: contents.bytesize
      }
    end
  end
end
