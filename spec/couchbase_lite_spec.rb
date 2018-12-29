RSpec.describe CouchbaseLite do
  it 'has a version number' do
    expect(CouchbaseLite::VERSION).not_to be nil
  end

  it 'exposes a database API' do
    expect(CouchbaseLite::Database).to be
  end

  describe '#litecore_version' do
    subject { described_class.litecore_version }

    it { is_expected.to be_a(String) }
  end
end
