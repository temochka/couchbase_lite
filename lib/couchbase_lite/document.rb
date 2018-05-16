module CouchbaseLite
  class Document
    include ErrorHandling

    attr_reader :c4_document

    def initialize(c4_document)
      @c4_document = c4_document
    end

    def id
      c4_document.id.to_s
    end

    def rev
      c4_document.rev.to_s
    end

    def sequence
      c4_document.sequence
    end

    def body(symbolize_names: true)
      c4_slice = blank_err { |e| FFI.c4doc_bodyAsJSON(c4_document, false, e)  }
      JSON.parse(c4_slice.to_s, symbolize_names: symbolize_names)
    end

    def deleted?
      c4_document.deleted?
    end
  end
end
