module CouchbaseLite
  class DocumentEnumerator
    include Enumerable
    include ErrorHandling

    def initialize(database, since: 0, **options)
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

    private

    def make_enumerator(c4_doc_enumerator)
      ::Enumerator.new do |docs|
        error = FFI::C4Error.new

        while FFI.c4enum_next(c4_doc_enumerator, error)
          c4_doc = null_err do |e|
            FFI.c4enum_getDocument(c4_doc_enumerator, e)
          end

          doc = Document.new(c4_doc)

          docs << doc
        end
      end
    end
  end
end
