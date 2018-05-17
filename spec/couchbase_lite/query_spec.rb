require 'spec_helper'

RSpec.describe CouchbaseLite::Query do
  include_context 'CBLite db'

  def query(titles, ast)
    db.query(titles, ast)
  end

  describe 'constant query' do
    let(:n) { 5 }
    before { n.times { |i| db.insert(i.to_s, foo: 'bar') } }

    it 'selects a constant for each record' do
      expect(query(%w($1), what: [1])).to select_records(Array.new(n) { { '$1' => 1 } })
    end
  end
end
