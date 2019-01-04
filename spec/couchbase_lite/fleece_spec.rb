require 'spec_helper'

RSpec.describe CouchbaseLite::Fleece do
  let(:data) { { foo: 'bar', buz: 'moo' } }
  let(:dump_options) { {} }
  let(:dumped) { described_class.dump(data, dump_options) }
  let(:parsed) { described_class.parse(dumped, symbolize_names: true) }

  describe '.dump' do
    subject { dumped }

    it { is_expected.to be_a(String) }

    context 'when stringify is set to false' do
      let(:dump_options) { { stringify: false } }

      it { is_expected.to be_a(CouchbaseLite::FFI::C4SliceResult) }
    end
  end

  describe '.parse' do
    subject { parsed }

    it { is_expected.to eq(data) }
  end
end
