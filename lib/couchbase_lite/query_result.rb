module CouchbaseLite
  class QueryResult
    include Enumerable

    attr_reader :query, :enumerator

    def initialize(query, c4_enumerator)
      @query = query
      @c4_enumerator = c4_enumerator
      @enumerator = make_enumerator(c4_enumerator, query.titles)
    end

    def refresh
      e = FFI::C4Error.new
      new_ptr = FFI.c4queryenum_refresh(@c4_enumerator, e)
      return if new_ptr.null?
      self.class.new(query, new_ptr)
    end

    def to_a
      enumerator.to_a
    end

    def next
      enumerator.next
    end

    def size
      error = FFI::C4Error.new
      FFI.c4queryenum_getRowCount(@c4_enumerator, error)
    end

    protected

    attr_reader :c4_enumerator_ref

    def make_enumerator(c4_enumerator, column_titles)
      Enumerator.new do |rows|
        error = FFI::C4Error.new

        while FFI.c4queryenum_next(c4_enumerator, error)
          columns_as_json = Enumerator.new do |columns|
            begin
              columns << FFI.flarrayiter_get_value(c4_enumerator[:columns])
            end while FFI.flarrayiter_next(c4_enumerator[:columns])
          end.map { |v| FFI.flvalue_to_json(v).to_s }

          rows << column_titles.zip(JSON.parse("[#{columns_as_json.join(',')}]")).to_h
        end
      end
    end
  end
end
