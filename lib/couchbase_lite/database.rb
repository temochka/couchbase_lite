module CouchbaseLite
  class Database
    extend ErrorHandling
    include ErrorHandling

    def self.open(path)
      path = FFI::C4String.from_string(path)
      key = FFI::C4EncryptionKey.new
      key[:algorithm] = :kC4EncryptionNone
      config = FFI::C4DatabaseConfig.new
      config[:flags] = FFI::C4DB_Create | FFI::C4DB_AutoCompact
      config[:versioning] = :kC4RevisionTrees
      config[:encryptionKey] = key

      ptr = null_err { |e| FFI.c4db_open(path, config, e) }
      auto_ptr = FFI::C4Database.auto(ptr)

      new(auto_ptr)
    end

    def close
      false_err { |e| FFI.c4db_close(c4_database, e) }
    end

    def insert(id, json_body)
      document = transaction do
        null_err do |e|
          FFI.c4doc_create(c4_database,
                           FFI::C4String.from_string(id),
                           json_to_fleece(json_body),
                           0,
                           e)
        end
      end
      
      document[:docID].to_s
    ensure
      FFI.c4doc_free(document) if document
    end

    def get(id)
      c4_document = get_document(id)
      
      Document.from_native(c4_document) if c4_document
    ensure
      FFI.c4doc_free(c4_document) if c4_document
    end

    def update(id, json_body)
      old_doc = get_document(id)
      doc = transaction do
        null_err { |e| FFI.c4doc_update(old_doc, json_to_fleece(json_body), 0, e) }
      end
      FFI.c4doc_free(doc) if doc
      true
    ensure
      FFI.c4doc_free(old_doc) if old_doc
    end

    def query(text)
      n1ql = N1ql::Query.new(text)
      Query.new(self, n1ql.ast, n1ql.titles)
    end

    def register_observer(trigger, observer = nil, &block)
      @observers[trigger] ||= []
      @observers[trigger] << (observer || block)
    end

    def create_index(name, type, expressions)
      raise ArgumentError unless name && !name.empty?

      c4_type = case type
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

    private

    attr_reader :c4_database

    def initialize(c4_database)
      @c4_database = c4_database
      @observers = {}
    end

    def transaction(persist = true)
      false_err { |e| FFI::c4db_beginTransaction(c4_database, e) }
      begin
        yield
      ensure
        false_err { |e| FFI::c4db_endTransaction(c4_database, persist, e) }
        notify_observers(:commit)
      end
    end

    def notify_observers(action)
      @observers.fetch(action, []).each(&:call)
    end

    def json_to_fleece(json)
      blank_err { |e| FFI.c4db_encodeJSON(c4_database, FFI::C4String.from_string(json), e) }
    end

    def get_document(id)
      null_err { |e| FFI.c4doc_get(c4_database, FFI::C4String.from_string(id), true, e) }
    end
  end
end
