require 'tmpdir'

RSpec.shared_context 'CBLite db' do
  let(:_tmp_dir) { Dir.mktmpdir }
  let(:cblite_db_options) { {} }
  let(:db) { CouchbaseLite::Database.open(File.join(_tmp_dir, 'test'), **cblite_db_options) }

  around(:example) do |ex|
    begin
      db
      ex.run
    ensure
      FileUtils.remove_entry_secure(_tmp_dir)
    end
  end
end
