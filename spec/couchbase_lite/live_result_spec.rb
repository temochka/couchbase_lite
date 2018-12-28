require 'spec_helper'

RSpec.describe CouchbaseLite::LiveResult do
  include_context 'CBLite db test'
  include_context 'simple dataset'

  let(:query) { n1ql('SELECT number ORDER BY number LIMIT 3') }

  context 'without callback' do
    subject(:live) { query.run.live }

    it 'auto-refreshes once the change occurs' do
      original = live.result
      expect(original).to be_a(CouchbaseLite::QueryResult)
      expect(original.first).to eq('number' => 0)
      db.update('0', number: -1)
      sleep 0.1
      expect(live.result).to_not eq(original)
      expect(live.result.first).to eq('number' => -1)
    end
  end

  context 'with callback' do
    let(:snapshots) { [] }
    subject!(:live) do
      query.run.live { |r| snapshots << r.map { |row| row['number'] } }
    end

    it 'runs callback on every commit' do
      db.delete('0')
      sleep 0.1
      db.delete('1')
      sleep 0.1
      expect(snapshots).to eq [[0, 1, 2], [1, 2, 3], [2, 3, 4]]
    end
  end
end
