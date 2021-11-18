describe Polyline::Normalizer::Distance do
  describe '#normalized' do
    it 'normalizes an encoded path by point distance' do
      encoded = read_fixture('pincher_creek/input.line')
      expect(described_class.normalize(encoded)).to eq(read_fixture('pincher_creek/output.line'))
    end

    it 'properly sets the start and finish points' do
      described_class.normalize(read_fixture('cochrane/input.line'))
      expect(true).to eq(false)
    end
  end
end
