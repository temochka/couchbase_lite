require 'spec_helper'

RSpec.describe CouchbaseLite::Fleece do
  let(:data) { { foo: 'bar', buz: 'moo' } }
  let(:dumped) { described_class.dump(data) }
  let(:parsed) { described_class.parse(dumped, symbolize_names: true) }

  describe '.dump' do
    subject { dumped }

    it { is_expected.to be_a(String) }
  end

  describe '.parse' do
    subject { parsed }

    it { is_expected.to eq(data) }
  end
end
