module CouchbaseLite
  class Document
    attr_reader :id, :rev, :sequence, :attributes

    def self.from_native(c4_document)
      json = blank_err { |e| FFI.c4doc_bodyAsJSON(c4_document, false, e) }
      new(c4_document.id, c4_document.rev, c4_document.sequence, JSON.parse(json))
    end

    def initialize(id, rev, sequence, attributes)
      @id = id
      @rev = rev
      @sequence = sequence
      @attributes = OpenStruct.new(attributes)
    end
  end
end
