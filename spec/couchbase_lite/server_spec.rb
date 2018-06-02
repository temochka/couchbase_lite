require 'spec_helper'
require 'couchbase_lite/server'
require 'rack'

RSpec.describe CouchbaseLite::Server do
  context 'replication to a clean db' do
    include_context 'CBLite db test'
    include_context 'CBLite db', :db_replica
    include_context 'simple dataset'

    subject(:server) { CouchbaseLite::Server.new { |_| db } }
    let(:port) { 4666 }
    let(:client_socket_factory) { CouchbaseLite::ReplicatorSocketFactory.new(server: false) }

    around(:example) do |ex|
      EM.run do
        Rack::Handler.get('thin').run(server, Port: port) do |s|
          ex.run
        end
      end
    end

    it 'replicates database to the replica' do
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
end
