require 'spec_helper'

RSpec.describe CouchbaseLite::Database do
  include_context 'CBLite db test'

  let(:id) { SecureRandom.hex(8) }
  let(:body) { { foo: 'bar' } }
  let(:revision_prefix) { '1-' }
  let(:cblite_db_options) { {} }

  subject { db }

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
    subject(:query) { db.query(%w(foo), what: [%w(. foo)]) }

    it { is_expected.to be_a(CouchbaseLite::Query) }
    specify { expect(query.database).to eq(db) }
    specify { expect(query.titles).to eq(%w(foo)) }
    specify { expect(query.ast).to eq({ what: [%w(. foo)] }.to_json) }
  end

  describe '#add_observer' do
    let(:notifications) { [] }
    let(:observer) { ->(event) { notifications << event } }

    before do
      db.add_observer(observer, :call)
      doc = db.insert(id, body)
      db.delete(doc)
    end

    context 'standard async method' do
      it 'synchronously notifies observers on every commit' do
        expect(notifications.count).to eq 2
        expect(notifications.uniq).to eq %i(commit)
      end
    end

    context 'custom async method' do
      let(:queue) { Queue.new }
      let(:async_method) { ->(&block) { queue << block } }
      let(:async_loop) { -> { queue.pop.call } }
      let(:cblite_db_options) { { async: async_method } }

      it 'uses provided async method to delay notifications until later' do
        expect(queue.size).to eq 2
        2.times do
          expect { async_loop.call }.to change { notifications.size }.by(1)
        end
        expect(notifications.uniq).to eq %i(commit)
      end
    end
  end
end
