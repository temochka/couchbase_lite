require 'spec_helper'

RSpec.describe CouchbaseLite::Database do
  let(:tmpdir) { Dir.mktmpdir }
  let(:id) { SecureRandom.hex(8) }
  let(:body) { { foo: 'bar' } }
  let(:revision_prefix) { '1-' }
  after(:each) { FileUtils.remove_entry_secure(tmpdir) }

  subject(:db) { CouchbaseLite::Database.open(File.join(tmpdir, 'test')) }

  describe '.open' do
    it { is_expected.to be_a CouchbaseLite::Database }
  end

  describe '#close' do
    specify { expect { db.close }.to_not raise_error }
  end

  shared_examples_for 'document' do
    specify do
      expect(document).to be_a(CouchbaseLite::Document)
      expect(document.id).to eq(id)
      expect(document.rev).to start_with(revision_prefix)
      expect(document.body).to eq(body)
    end
  end

  describe '#insert' do
    subject(:document) { db.insert(id, body) }

    it_behaves_like 'document'
  end

  describe '#get' do
    subject(:document) { db.get(id) }

    context 'when doesn’t exist' do
      it { is_expected.to be_nil }
    end

    context 'when exists' do
      before { db.insert(id, body) }

      it_behaves_like 'document'
    end
  end

  describe '#update' do
    let(:old_body) { { change_me: true } }
    let!(:old_document) { db.insert(id, old_body) }
    let(:revision_prefix) { '2-' }

    context 'by id' do
      subject(:document) { db.update(id, body) }

      it_behaves_like 'document'
    end

    context 'by reference' do
      subject(:document) { db.update(old_document, body) }

      it_behaves_like 'document'
    end
  end

  describe '#delete' do
    subject!(:document) { db.insert(id, body) }

    it_behaves_like 'document'

    context 'by id' do
      let(:deleted_document) { db.delete(id) }

      specify do
        expect { deleted_document }.to change { db.get(id).deleted? }.to(true)
        expect(deleted_document).to be_deleted
        expect(deleted_document.id).to eq(id)
      end
    end

    context 'by reference' do
      let(:deleted_document) { db.delete(document) }

      specify do
        expect { deleted_document }.to change { db.get(id).deleted? }.to(true)
        expect(deleted_document).to be_deleted
        expect(deleted_document.id).to eq(id)
      end
    end
  end

  describe '#create_index' do
    context 'value index' do
      subject(:index) { db.create_index('by_foo', :val, [%w(. foo)].to_json) }

      it { is_expected.to be true }
    end

    context 'full-text index' do
      subject(:index) { db.create_index('by_foo', :fts, [%w(. foo)].to_json) }

      it { is_expected.to be true }
    end
  end

  describe '#query' do
    subject(:query) { db.query(%w(foo), select: [%w(. foo)]) }

    it { is_expected.to be_a(CouchbaseLite::Query) }
    specify { expect(query.db).to eq(db) }
    specify { expect(query.titles).to eq(%w(foo)) }
    specify { expect(query.ast).to eq({ select: [%w(. foo)] }.to_json) }
  end
end
