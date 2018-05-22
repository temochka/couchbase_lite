module CouchbaseLite
  class Query
    include Conversions
    include ErrorHandling

    attr_accessor :database, :ast, :titles

    def initialize(database, titles, ast)
      @database = database
      @titles = titles
      @ast = json(ast)

      c4_query_ptr = null_err do |e|
        FFI.c4query_new(database.c4_database,
                        FFI::C4String.from_string(@ast),
                        e)
      end
      @c4_query = FFI::C4Query.auto(c4_query_ptr)
    end

    def run(arguments = {})
      c4_enumerator = null_err do |e|
        FFI.c4query_run(@c4_query,
                        FFI::C4QueryOptions.new,
                        FFI::C4String.from_string(arguments.to_json),
                        e)
      end
      QueryResult.new(self, c4_enumerator)
    end
  end
end
