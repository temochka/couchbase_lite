require 'spec_helper'

RSpec.describe CouchbaseLite::Database do
  let(:tmpdir) { Dir.mktmpdir }
  after(:each) { FileUtils.remove_entry_secure(tmpdir) }

  subject(:db) { CouchbaseLite::Database.open(File.join(tmpdir, 'test')) }

  describe '.open' do
    it { is_expected.to be_a CouchbaseLite::Database }
  end

  describe '#close' do
    specify { expect { db.close }.to_not raise_error }
  end
end
