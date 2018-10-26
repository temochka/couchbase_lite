require 'spec_helper'
require 'couchbase_lite/server'
require 'rack'

RSpec.describe CouchbaseLite::Server do
  include_context 'CBLite db test'
  include_context 'CBLite db', :db_replica

  subject(:server) { CouchbaseLite::Server.new { |_| db } }
  let(:port) { 4666 }
  let(:client_socket_factory) { CouchbaseLite::ReplicatorSocketFactory.new(server: false) }

  around(:example) do |ex|
    EM.run do
      Rack::Handler.get('thin').run(server, Port: port)
      ex.run
    end
  end

  context 'replication from server' do
    include_context 'simple dataset'

    it 'replicates database to the replica' do
      expect(n1ql('SELECT *', db).run.to_a).to_not be_empty
      expect(n1ql('SELECT *', db_replica).run.to_a).to be_empty
      replicator = CouchbaseLite::Replicator.new(db_replica,
                                                 socket_factory: client_socket_factory,
                                                 url: "ws://localhost:#{port}/db")

      expect { replicator.start }.
        to run_until { replicator.status.level == :idle }.
          with_timeout(5).
          and_then {
            expect(n1ql('SELECT *', db).run.to_a).to eq(n1ql('SELECT *', db_replica).run.to_a)
            replicator.stop
          }.
          always { EM.stop }
    end
  end

  context 'replication from client' do
    include_context 'simple dataset', :db_replica

    it 'replicates database to the replica' do
      expect(n1ql('SELECT *', db).run.to_a).to be_empty
      expect(n1ql('SELECT *', db_replica).run.to_a).to_not be_empty
      replicator = CouchbaseLite::Replicator.new(db_replica,
                                                 socket_factory: client_socket_factory,
                                                 url: "ws://localhost:#{port}/db")

      expect { replicator.start }.
        to run_until { replicator.status.level == :idle }.
          with_timeout(5).
          and_then {
            expect(n1ql('SELECT *', db).run.to_a).to eq(n1ql('SELECT *', db_replica).run.to_a)
            replicator.stop
          }.
          always { EM.stop }
    end
  end

  context 'replication with conflicts' do
    let(:master_rev) { { answer: 'What is the most comfortable number of tentacles?' } }
    let(:replica_rev) { { answer: 'What is the best number of toppings on ice cream?' } }
    before do
      db.insert('42', master_rev)
      db_replica.insert('42', replica_rev)
    end

    it 'registers conflicts' do
      replicator = CouchbaseLite::Replicator.new(db_replica,
                                                 socket_factory: client_socket_factory,
                                                 url: "ws://localhost:#{port}/db")

      expect { replicator.start }.
        to run_until { replicator.status.level == :idle }.
          with_timeout(5).
          and_then {
            doc = db_replica.get('42')
            expect(doc).to be_conflicted

            conflicting_revs = db_replica.get_conflicts(doc)
            expect(conflicting_revs.size).to eq 2
            expect(conflicting_revs[0][:body]).to eq(replica_rev)
            expect(conflicting_revs[1][:body]).to eq(master_rev)

            db_replica.resolve_conflicts(doc, conflicting_revs.map { |r| r[:rev] }, body: { answer: 'Both.' })
            expect(doc).to_not be_conflicted

            reloaded_doc = db_replica.get('42')
            expect(reloaded_doc).to_not be_conflicted
            expect(reloaded_doc.body).to eq(answer: 'Both.')
            replicator.stop
          }.
          always { EM.stop }
    end
  end
end
