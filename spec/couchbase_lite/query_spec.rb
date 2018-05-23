require 'spec_helper'

RSpec.describe CouchbaseLite::Query do
  include_context 'CBLite db test'

  describe 'select constant' do
    include_context 'simple dataset'

    it 'selects a constant for each record' do
      expect(query(%w($1), what: [1])).to select_records(Array.new(n) { { '$1' => 1 } })
    end
  end

  describe 'select' do
    context 'without joins' do
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

        expect(n1ql('SELECT number WHERE ARRAY_COUNT(array)=$n-1')).
          to select_records([{ 'number' => n - 1 }]).
            with_arguments(n: n)

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

    context 'with joins' do
      before do
        load_dataset('names_100.json')
        load_dataset('states_titlecase.json')
      end

      it 'selects count' do
        text = <<-SQL
          SELECT
            person.name.first, state.name
          FROM
            person JOIN state ON state.abbreviation = person.contact.address.state
          WHERE
            LENGTH(person.name.first) >= 9
          ORDER BY person.name.first
        SQL

        expect(n1ql(text)).
          to select_records([{ 'first' => 'Cleveland', 'name' => 'California' },
                             { 'first' => 'Georgetta', 'name' => 'Ohio' },
                             { 'first' => 'Margaretta', 'name' => 'South Dakota' }])
      end
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
