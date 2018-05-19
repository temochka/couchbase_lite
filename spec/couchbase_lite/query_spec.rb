require 'spec_helper'

RSpec.describe CouchbaseLite::Query do
  include_context 'CBLite db'

  def query(titles, ast)
    db.query(titles, ast)
  end

  def n1ql(text)
    q = N1ql::Query.new(text)
    query(q.titles, q.ast)
  end

  shared_context 'simple dataset' do
    let(:n) { 20 }
    let(:records) do
      Array.new(n) do |i|
        { 'number' => i, 'flag_odd' => i.odd?, 'string' => "name_#{i}", 'array' => Array.new(i) { i } }
      end
    end

    before do
      records.each_with_index { |r, i| db.insert(i.to_s, r) }
    end
  end

  describe 'select constant' do
    include_context 'simple dataset'

    it 'selects a constant for each record' do
      expect(query(%w($1), what: [1])).to select_records(Array.new(n) { { '$1' => 1 } })
    end
  end

  describe 'select' do
    include_context 'simple dataset'

    it 'returns matching records' do
      expect(n1ql('SELECT foo._id AS id, foo.* AS doc FROM foo')).
        to select_records(records.map { |r| { 'id' => r['number'].to_s, 'doc' => r } })

      expect(n1ql('SELECT number WHERE flag_odd=true')).
        to select_records(Array.new(n / 2) { |i| { 'number' => i * 2 + 1 } })

      expect(n1ql('SELECT MAX(number) as max WHERE flag_odd=false')).
        to select_records([{ 'max' => n.odd? ? n - 1 : n - 2 }])

      expect(n1ql('SELECT number WHERE string LIKE $pattern')).
        to select_records([{ 'number' => n - 1 }]).
          with_arguments(pattern: "%_#{n - 1}")

      # OFFSET AND LIMIT
      expect(n1ql("SELECT number LIMIT $limit")).
        to select_records((0...(n / 2)).map { |i| { 'number' => i } }).
          with_arguments(limit: n / 2)
      expect(n1ql("SELECT number LIMIT $limit OFFSET $offset")).
        to select_records(((n / 2)...n).map { |i| { 'number' => i } }).
          with_arguments(limit: n / 2, offset: n / 2)
      expect(n1ql("SELECT number ORDER BY number DESC LIMIT $limit")).
        to select_records((10..19).to_a.reverse.map { |i| { 'number' => i } }).
          with_arguments(limit: n / 2)
    end
  end

  describe 'count' do
    include_context 'simple dataset'

    it 'counts all records' do
      expect(n1ql('SELECT COUNT(*) AS count')).to select_records([{ 'count' => n }])
    end

    it 'counts all matching records' do
      expect(n1ql("SELECT COUNT(*) AS count WHERE number >= $n")).
        to select_records([{ 'count' => n / 2 }]).with_arguments(n: n / 2)
    end
  end
end
