module CouchbaseLite
  class DocumentEnumerator
    include Enumerable
    include ErrorHandling

    def initialize(c4_doc_enumerator)
      @enumerator = make_enumerator(c4_doc_enumerator)
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

          docs << Document.new(c4_doc)
        end
      end
    end
  end
end
