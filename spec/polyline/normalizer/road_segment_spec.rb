describe Polyline::Normalizer::RoadSegment do
  subject { described_class.new(input) }

  Helpers::Fixtures::PATH.glob('case_*') do |path|
    describe(path.basename.to_s) do
      let(:input) { read_fixture(path.join('input.line')) }
      let(:output) { read_fixture(path.join('output.line')) }

      it 'returns the correct output' do
        expect(subject.normalize).to eq(output)
      end
    end
  end
end
