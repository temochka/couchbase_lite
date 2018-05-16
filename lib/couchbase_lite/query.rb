module CouchbaseLite
  class Query
    include Conversions
    include ErrorHandling

    attr_accessor :db, :ast, :titles

    def initialize(db, titles, ast)
      @db = db
      @titles = titles
      @ast = json(ast)

      c4_query_ptr = null_err do |e|
        FFI.c4query_new(db.c4_database,
                        FFI::C4String.from_string(@ast),
                        e)
      end
      @c4_query = FFI::C4Query.auto(c4_query_ptr)
    end

    def run(arguments = {})
      c4_enumerator_ptr = null_err do |e|
        FFI.c4query_run(@c4_query,
                        FFI::C4QueryOptions.new,
                        FFI::C4String.from_string(arguments.to_json),
                        e)
      end
      c4_enumerator = FFI::C4QueryEnumerator.auto(c4_enumerator_ptr)
      QueryResult.new(self, c4_enumerator)
    end
  end
end
