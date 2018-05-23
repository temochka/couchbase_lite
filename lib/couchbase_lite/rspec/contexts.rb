require 'tmpdir'

RSpec.shared_context 'CBLite db' do |name|
  let(:"_tmp_dir#{name}") { Dir.mktmpdir }

  let(:cblite_db_options) { {} }
  let(name) { CouchbaseLite::Database.open(File.join(send(:"_tmp_dir#{name}"), 'test'), **cblite_db_options) }

  around(:example) do |ex|
    begin
      send(name)
      ex.run
    ensure
      FileUtils.remove_entry_secure(send(:"_tmp_dir#{name}"))
    end
  end
end

RSpec.shared_context 'CBLite db test' do
  include_context 'CBLite db', :db

  def query(titles, ast)
    db.query(titles, ast)
  end
  alias_method :_query, :query

  if defined?(N1ql)
    def n1ql(text)
      q = N1ql::Query.new(text)
      _query(q.titles, q.ast)
    end
  end

end

RSpec.shared_context 'simple dataset' do |size = 20|
  let(:n) { size }
  let(:records) do
    Array.new(n) do |i|
      { 'number' => i, 'flag_odd' => i.odd?, 'string' => "name_#{i}", 'array' => Array.new(i) { i } }
    end
  end

  before do
    records.each_with_index { |r, i| db.insert(i.to_s, r) }
  end
end
