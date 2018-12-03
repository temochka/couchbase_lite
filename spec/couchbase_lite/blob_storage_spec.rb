require 'spec_helper'

RSpec.describe CouchbaseLite::BlobStorage do
  include_context 'CBLite db', :db

  subject(:blob_storage) { described_class.new(db) }
  let(:contents) { 'CouchBase Lite Blob Storage Test и друзья' }

  it { is_expected.to be }

  describe '#store' do
    subject(:ref) { blob_storage.store(contents, content_type: 'text/plain') }

    it 'returns the string key of a stored object' do
      is_expected.to be_a(Hash)
      expect(ref[:@type]).to eq('blob')
      expect(ref[:length]).to eq(contents.bytesize)
      expect(ref[:content_type]).to eq('text/plain')
      expect(ref[:digest]).to be_a(String)
      expect(ref[:digest]).to start_with('sha1-')
    end
  end

  describe '#read' do
    let(:ref) { blob_storage.store(contents) }

    subject { blob_storage.read(ref).force_encoding('utf-8') }

    it { is_expected.to eq(contents) }
  end

  describe '#open' do
    it 'returns an IO-like object that wraps the underlying Couchbase Lite stream'
  end
end
