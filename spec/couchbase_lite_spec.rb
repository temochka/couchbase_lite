RSpec.describe CouchbaseLite do
  it 'has a version number' do
    expect(CouchbaseLite::VERSION).not_to be nil
  end

  it 'exposes a database API' do
    expect(CouchbaseLite::Database).to be
  end
end
