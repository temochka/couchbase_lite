require 'spec_helper'

RSpec.describe CouchbaseLite::QueryResult do
  include_context 'CBLite db test'
  include_context 'simple dataset'

  let(:id) { '1' }
  subject(:result) { n1ql('SELECT number WHERE _id=$id').run(id: id) }

  it 'acts as a stateful enumerator' do
    expect(result.first).to eq('number' => 1)
    expect(result.first).to be_nil
  end

  it 'implements enumerable' do
    expect(result.map { |n| n['number'] * 2 }.reduce(0, &:+)).to eq 2
  end

  describe '#to_a' do
    it 'returns an array of all matches' do
      expect(result.to_a).to eq [{ 'number' => 1 }]
    end
  end

  describe '#size' do
    subject(:result) { n1ql('SELECT *').run }

    specify { expect(result.size).to eq n }
  end

  describe '#live' do
    it 'returns a LiveResult instance' do
      expect(result.live).to be_a(CouchbaseLite::LiveResult)
    end
  end

  describe '#refresh' do
    subject(:refreshed) { result.refresh }

    before { result }

    context 'when nothing changed' do
      it 'returns the same result' do
        is_expected.to be_a(CouchbaseLite::QueryResult)
        is_expected.to eq(result)
      end
    end

    context 'when another document changed' do
      before do
        doc = db.get('2')
        db.update('2', doc.body.merge(number: 42))
      end

      it 'returns the same result' do
        is_expected.to be_a(CouchbaseLite::QueryResult)
        is_expected.to eq(result)
      end
    end

    context 'when changed' do
      before do
        doc = db.get(id)
        db.update(id, doc.body.merge(number: 42))
      end

      it 'returns a new result' do
        is_expected.to be_a(CouchbaseLite::QueryResult)
        is_expected.to_not eq(result)
        expect(refreshed.first).to eq('number' => 42)
      end
    end
  end
end
