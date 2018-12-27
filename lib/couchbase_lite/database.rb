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

    def put(id,
            json_body,
            revision_flags: {},
            existing_revision: false,
            allow_conflict: false,
            history: [],
            save: true,
            max_rev_tree_depth: 0,
            remote_db_id: 0)
      request = FFI::C4DocPutRequest.new
      c4_document = transaction do
        null_err do |e|
          request[:docID] = FFI::C4String.from_string(id)
          request[:body] = json_body ? json_to_fleece(json(json_body)) : FFI::C4Slice.null
          request[:revFlags] = FFI::C4RevisionFlags.make(revision_flags)
          request[:existingRevision] = existing_revision
          request[:allowConflict] = allow_conflict
          request[:history] = FFI::C4String.array(history)
          request[:historyCount] = history.count
          request[:save] = save
          request[:maxRevTreeDepth] = max_rev_tree_depth
          request[:remoteDBID] = remote_db_id

          FFI.c4doc_put(c4_database, request, nil, e)
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

    def save(document, max_rev_tree_depth: 5)
      raise ArgumentError, 'Must be a Document instance' unless document.is_a?(Document)
      false_err do |e|
        FFI.c4doc_save(document.c4_document, max_rev_tree_depth, e)
      end
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

    def conflicts(since = 0)
      c4_doc_enumerator = null_err do |e|
        FFI.c4db_enumerateChanges(c4_database,
                                  since,
                                  FFI::C4EnumeratorOptions.make(only_conflicts: true, bodies: true),
                                  e)
      end

      enumerator = DocumentEnumerator.new(FFI::C4DocEnumerator.auto(c4_doc_enumerator))
      enumerator.lazy.map { |doc| get_conflicts(doc) }
    end

    def get_conflicts(document)
      return [] unless document.conflicted?

      leafs = [{ rev: document.rev, body: document.body }]

      while document.next_leaf_rev
        leafs << { rev: document.selected_rev.id.to_s, body: document.body }
      end

      leafs
    end

    def resolve_conflicts(document, revisions, body: nil, max_depth: 20)
      transaction do
        revisions.reduce do |winning_rev, losing_rev|
          false_err do |e|
            FFI.c4doc_resolveConflict(document.c4_document,
                                      FFI::C4String.from_string(winning_rev),
                                      FFI::C4String.from_string(losing_rev),
                                      json_to_fleece(json(body)),
                                      0,
                                      e)
          end
        end

        false_err do |e|
          FFI.c4doc_save(document.c4_document, max_depth, e)
        end
      end
    end

    def query(titles, ast)
      Query.new(self, titles, ast)
    end

    def blob_storage
      BlobStorage.new(self)
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
