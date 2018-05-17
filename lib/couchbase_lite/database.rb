module CouchbaseLite
  class Database
    attr_reader :c4_database

    extend ErrorHandling

    include Conversions
    include ErrorHandling
    include Observable

    def self.open(path, **kwargs)
      path = FFI::C4String.from_string(path)
      key = FFI::C4EncryptionKey.new
      key[:algorithm] = :kC4EncryptionNone
      config = FFI::C4DatabaseConfig.new
      config[:flags] = FFI::C4DB_Create | FFI::C4DB_AutoCompact
      config[:versioning] = :kC4RevisionTrees
      config[:encryptionKey] = key

      ptr = null_err { |e| FFI.c4db_open(path, config, e) }
      auto_ptr = FFI::C4Database.auto(ptr)

      new(auto_ptr, **kwargs)
    end

    def close
      false_err { |e| FFI.c4db_close(c4_database, e) }
    end

    def insert(id, json_body)
      c4_document = transaction do
        null_err do |e|
          FFI.c4doc_create(c4_database,
                           FFI::C4String.from_string(id),
                           json_to_fleece(json(json_body)),
                           0,
                           e)
        end
      end

      Document.new(c4_document)
    end

    def get(id)
      Document.new(get_document(id))
    rescue DocumentNotFound
      nil
    end

    def update(document, json_body)
      old_c4_document = document.is_a?(Document) ? document.c4_document : get_document(document)

      new_c4_document = transaction do
        null_err do |e|
          FFI.c4doc_update(old_c4_document, json_to_fleece(json(json_body)), old_c4_document.flags, e)
        end
      end

      Document.new(new_c4_document)
    end

    def delete(document)
      c4_document = document.is_a?(Document) ? document.c4_document : get_document(document)
      deleted_c4_document = transaction do
        false_err do |e|
          FFI.c4doc_update(c4_document, FFI::C4Slice.null, c4_document.flags | FFI::C4DOC_DocDeleted, e)
        end
      end
      Document.new(deleted_c4_document)
    end

    def create_index(name, type, expressions)
      raise ArgumentError unless name && !name.empty?

      c4_type = case type.to_s
                when 'val'
                  :kC4ValueIndex
                when 'fts'
                  :kC4FullTextIndex
                when 'geo'
                  :kC4GeoIndex
                end
      raise ArgumentError unless c4_type

      false_err do |e|
        FFI.c4db_createIndex(c4_database,
                             FFI::C4String.from_string(name),
                             FFI::C4String.from_string(expressions),
                             c4_type,
                             nil,
                             e)
      end
    end

    def query(titles, ast)
      Query.new(self, titles, ast)
    end

    private

    def initialize(c4_database, async: ->(&block) { block.call })
      @c4_database = c4_database
      @async = async
    end

    def transaction(persist = true)
      false_err { |e| FFI::c4db_beginTransaction(c4_database, e) }
      begin
        yield
      ensure
        false_err { |e| FFI::c4db_endTransaction(c4_database, persist, e) }

        @async.call do
          changed
          notify_observers(:commit)
        end

        true
      end
    end

    def json_to_fleece(json)
      blank_err { |e| FFI.c4db_encodeJSON(c4_database, FFI::C4String.from_string(json), e) }
    end

    def get_document(id)
      null_err { |e| FFI.c4doc_get(c4_database, FFI::C4String.from_string(id), true, e) }
    end
  end
end
