# Couchbase Lite for Ruby

[![CircleCI](https://circleci.com/gh/temochka/couchbase_lite/tree/master.svg?style=svg)](https://circleci.com/gh/temochka/couchbase_lite/tree/master)

This is an experimental wrapper of the [Couchbase Lite Core](https://github.com/couchbase/couchbase-lite-core) C library for Ruby. 

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'couchbase_lite', github: 'temochka/couchbase_lite'
```

And then execute:

    $ bundle

The `couchbase_lite` gem is not published on Rubygems.

## Usage

*Note: You must have a compiled version of the [Couchbase Lite Core library](https://github.com/couchbase/couchbase-lite-core) for your platform on your LD_LIBRARY_PATH.*

Create/open a database:

``` ruby
db = CouchbaseLite::Database.open('database')
```

CRUD documents:

``` ruby
id = SecureRandom.uuid
inserted_doc = db.insert(id, key: 'value')
read_doc = db.get(id)
updated_doc = db.update(id, key: 'new_value')

db.delete(id)
```

AST queries:

``` ruby
db.query(%w(foo), what: [%w(. foo)])
```

N1QL queries (requires the [n1ql](https://github.com/temochka/n1ql) gem):

``` ruby
query = N1ql::Query.new('SELECT foo._id AS id, foo.* AS doc FROM foo')
db.query(query.titles, query.ast)
```

For more features (live queries, replication, etc.), see the specs.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/temochka/couchbase_lite.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
