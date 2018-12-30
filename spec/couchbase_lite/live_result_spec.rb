require 'spec_helper'

RSpec.describe CouchbaseLite::LiveResult do
  shared_examples_for 'live result' do
    include_context 'CBLite db test'
    include_context 'simple dataset'

    let(:limit) { 3 }

    context 'without callback' do
      subject(:live) { result.live }

      it 'auto-refreshes once the change occurs' do
        original = live.result
        expect(original).to be_a(result.class)
        expect(original.first).to eq('number' => 0)
        expect { db.update('0', number: 42) }.to have_side_effect { live.result != original }.with_timeout(5)
        expect(live.result.first).to eq('number' => 1)
      end
    end

    context 'with callback' do
      let(:snapshots) { [] }
      subject!(:live) do
        result.live { |r| snapshots << r.map { |row| row['number'] }.take(limit) }
      end

      it 'runs callback on every commit' do
        2.times do |i|
          original = live.result
          expect { db.delete(i.to_s) }.to have_side_effect { live.result != original }.with_timeout(5)
        end
        expect(snapshots.uniq).to eq [[0, 1, 2], [1, 2, 3], [2, 3, 4]]
      end
    end
  end

  context 'using with a query' do
    let(:result) { n1ql('SELECT number ORDER BY number LIMIT $l').run(l: limit) }

    it_behaves_like 'live result'
  end

  context 'using with an enumerator' do
    let(:result) { db.documents(bodies: true) { |doc| { 'number' => doc.body[:number] } } }

    it_behaves_like 'live result'
  end
end
