module CouchbaseLite
  class DocumentEnumerator
    DEFAULT_MAPPER = proc { |doc| doc.itself }

    include Enumerable
    include ErrorHandling

    def initialize(database, since: 0, **options, &mapper)
      @database = database
      @options = options
      @since = since
      @mapper = mapper || DEFAULT_MAPPER

      c4_doc_enumerator = null_err do |e|
        FFI.c4db_enumerateChanges(database.c4_database,
                                  since,
                                  FFI::C4EnumeratorOptions.make(options),
                                  e)
      end

      @enumerator = make_enumerator(FFI::C4DocEnumerator.auto(c4_doc_enumerator))
    end

    def next
      @enumerator.next
    end

    def each(&block)
      @enumerator.each(&block)
    end

    def live(&block)
      LiveResult.new(@database, self, &block)
    end

    def refresh
      self.class.new(@database, since: @since, **@options, &@mapper)
    end

    private

    def make_enumerator(c4_doc_enumerator)
      ::Enumerator.new do |docs|
        error = FFI::C4Error.new

        while FFI.c4enum_next(c4_doc_enumerator, error)
          c4_doc = null_err do |e|
            FFI.c4enum_getDocument(c4_doc_enumerator, e)
          end

          doc = Document.new(c4_doc)

          docs << @mapper.call(doc)
        end
      end
    end
  end
end
