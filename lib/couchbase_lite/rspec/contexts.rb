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

  def query(titles, ast, database = db)
    database.query(titles, ast)
  end
  alias_method :_query, :query

  if defined?(N1ql)
    def n1ql(text, database = db)
      q = N1ql::Query.new(text)
      _query(q.titles, q.ast, database)
    end
  end
end

RSpec.shared_context 'simple dataset' do |db_name = 'db', size = 20|
  let(:n) { size }
  let(:records) do
    Array.new(n) do |i|
      { 'number' => i, 'flag_odd' => i.odd?, 'string' => "name_#{i}", 'array' => Array.new(i) { i } }
    end
  end

  before do
    records.each_with_index { |r, i| send(db_name).insert(i.to_s, r) }
  end
end

RSpec.shared_context 'revision conflicts' do |db_name = 'db'|
  let(:conflict_id) { '1' }

  before do
    db = public_send(db_name)

    db.put(conflict_id, { foo: 'bar' })
    db.put(conflict_id,
           { foo: 'buz' },
           existing_revision: true,
           allow_conflict: true,
           history: ['1-0b265579fcb1b06526a7649efae41c8812f4200d'],
           remote_db_id: 1)
  end

  let(:conflicted_document) { db.get(conflict_id) }
end
