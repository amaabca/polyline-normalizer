describe Polyline::Normalizer::Distance do
  let(:encoded) { read_fixture('pincher_creek/input.line') }
  subject { described_class.new(reduction_factor: 5) }

  describe '#normalized' do
    it 'normalizes an encoded path by point distance' do
      expect(subject.normalize(encoded)).to eq(read_fixture('pincher_creek/output.line'))
    end
  end
end
