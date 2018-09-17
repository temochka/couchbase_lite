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

    def flags
      c4_document.flags
    end

    def sequence
      c4_document.sequence
    end

    def deleted?
      c4_document.deleted?
    end

    def conflicted?
      c4_document.conflicted?
    end

    def selected_rev
      c4_document.selected_rev
    end

    def next_leaf_rev
      e = FFI::C4Error.new
      ret = FFI.c4doc_selectNextLeafRevision(c4_document, false, true, e)
      raise LibraryError.for(e) if !ret && e.code != 0
      ret
    end

    def body(symbolize_names: true)
      c4_slice = blank_err { |e| FFI.c4doc_bodyAsJSON(c4_document, false, e) }
      JSON.parse(c4_slice.to_s, symbolize_names: symbolize_names)
    end
  end
end
