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

  describe '#put' do
    context 'when inserting a new revision' do
      subject(:document) { db.put(id, body) }

      it_behaves_like 'document'
    end

    context 'when inserting an existing revision' do
      let(:rev) { '1-0b265579fcb1b06526a7649efae41c8812f4200d' }

      subject(:document) do
        db.put(id,
               body,
               revision_flags: { leaf: true },
               existing_revision: true,
               history: [rev])
      end

      it_behaves_like 'document'

      specify { expect(document.rev).to eq rev }
    end

    context 'when inserting a deleted revision' do
      let(:original) { db.put(id, body) }

      subject(:document) do
        db.put(id, nil, revision_flags: { deleted: true }, history: [original.rev])
      end

      it { is_expected.to be_deleted }
    end

    context 'when inserting a conflicted revision' do
      let(:original) { db.put(id, body) }
      let(:conflicting_body) { { bar: 'buz' } }

      before do
        db.update(original, conflicting_body)
      end

      subject(:document) do
        db.put(id,
               nil,
               revision_flags: { leaf: true },
               existing_revision: true,
               allow_conflict: true,
               history: ['2-0b265579fcb1b06526a7649efae41c8812f4200d', original.rev])
      end

      it { is_expected.to be_conflicted }
    end
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

  describe '#documents' do
    include_context 'simple dataset', 'db', 42

    subject(:documents) { db.documents }

    before do
      db.update('0', body)
    end

    it { is_expected.to be_a(CouchbaseLite::DocumentEnumerator) }
    specify { expect(documents.count).to eq 42 }
    specify { expect(documents.map(&:id)).to eq [*1...42, 0].map(&:to_s) }
  end

  describe '#conflicts' do
    subject(:conflicts) { db.conflicts.to_a }

    context 'when there are no conflicts' do
      it { is_expected.to be_empty }
    end

    context 'when there is one conflict' do
      include_context 'revision conflicts'

      subject(:conflict) { conflicts.first }

      specify { expect(conflicts.count).to eq 1 }

      it { is_expected.to match([{ body: { foo: 'bar' }, rev: String }, { body: { foo: 'buz' }, rev: String }]) }
    end
  end

  describe '#get_conflicts' do
    subject(:conflicts) { db.get_conflicts(document) }

    context 'when the document is not conflicted' do
      let(:document) { db.insert(id, body) }

      it { is_expected.to be_empty }
    end

    context 'when the document is conflicted' do
      include_context 'revision conflicts'

      let(:document) { conflicted_document }

      it { is_expected.to match([{ body: { foo: 'bar' }, rev: String }, { body: { foo: 'buz' }, rev: String }]) }
    end
  end

  describe '#resolve_conflicts' do
    context 'when the document is not conflicted' do
      let(:original) { db.insert(id, body) }
      let(:update) { db.update(original, body) }

      it 'raises an error' do
        expect(original.rev).to_not eq(update.rev)
        expect { db.resolve_conflicts(update, [original.rev, update.rev]) }.to raise_error(CouchbaseLite::LibraryError)
      end
    end

    context 'when the document is conflicted' do
      include_context 'revision conflicts'

      let(:conflicting_revs) { db.get_conflicts(conflicted_document) }

      it 'resolves conflicts' do
        expect { db.resolve_conflicts(conflicted_document, conflicting_revs.map { |r| r[:rev] }, body: { x: 'y' }) }.
          to change { conflicted_document.conflicted? }.from(true).to(false)

        reloaded_doc = db.get(conflicted_document.id)
        expect(reloaded_doc).to_not be_conflicted
        expect(reloaded_doc.body).to eq(x: 'y')
      end
    end
  end

  describe '#query' do
    subject(:query) { db.query(%w(foo), what: [%w(. foo)]) }

    it { is_expected.to be_a(CouchbaseLite::Query) }
    specify { expect(query.database).to eq(db) }
    specify { expect(query.titles).to eq(%w(foo)) }
    specify { expect(query.ast).to eq({ what: [%w(. foo)] }.to_json) }
  end

  describe '#blob_storage' do
    subject(:blob_storage) { db.blob_storage }

    it { is_expected.to be_a(CouchbaseLite::BlobStorage) }
  end

  describe '#add_observer' do
    let(:changes) { [] }
    let(:seqs) { [] }
    let(:notifications) { [] }
    let(:observer) do
      ->(event, seq, num_changes) do
        notifications << event
        changes << num_changes
        seqs << seq
      end
    end

    before do
      db.add_observer(observer, :call)
      db.insert(id, body)
      db.insert("#{id}_alt", body)
    end

    context 'standard async method' do
      it 'asynchronously notifies observers within a reasonable amount of time' do
        sleep 0.1
        expect(changes.reduce(:+)).to eq 2
        expect(notifications.uniq).to eq %i(commit)
      end
    end

    context 'custom async method' do
      let(:queue) { Queue.new }
      let(:async_method) { ->(&block) { queue << block } }
      let(:cblite_db_options) { { async: async_method } }
      let(:worker_loop) { Thread.new { loop { queue.pop.call } } }

      after do
        worker_loop.exit
      end

      it 'uses provided async method to delay notifications until later' do
        expect(queue.size).to eq 1
        expect { worker_loop; sleep 0.1 }.
          to change { notifications.size }.by(1).
          and change { changes.reduce(0, :+) }.by(2)
        expect(notifications.uniq).to eq %i(commit)
      end
    end
  end
end
