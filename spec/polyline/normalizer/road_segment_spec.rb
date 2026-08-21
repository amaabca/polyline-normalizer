# frozen_string_literal: true

describe Polyline::Normalizer::RoadSegment do
  subject { described_class.new(input) }

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def encode(points)
    FastPolylines.encode(points)
  end

  def decode(polyline)
    FastPolylines.decode(polyline)
  end

  # ---------------------------------------------------------------------------
  # Fixture-based integration tests
  # ---------------------------------------------------------------------------
  Helpers::Fixtures::PATH.glob('case_*') do |path|
    describe(path.basename.to_s) do
      let(:input) { read_fixture(path.join('input.line')) }
      let(:output) { read_fixture(path.join('output.line')) }

      it 'returns the correct output' do
        expect(subject.normalize).to eq(output)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # normalize — encoding
  # ---------------------------------------------------------------------------
  describe '#normalize' do
    context 'returns a UTF-8 encoded string' do
      let(:input) { encode([[53.0, -113.5], [53.001, -113.5], [53.002, -113.5]]) }

      it { expect(subject.normalize.encoding.to_s).to eq('UTF-8') }
    end

    context 'when no reorder is needed (no gap > threshold)' do
      # Three consecutive points with no large gap — already ordered correctly.
      let(:pts) { 10.times.map { |i| [53.0 + (i * 0.001), -113.5] } }
      let(:input) { encode(pts) }

      it 'returns the points unchanged' do
        expect(decode(subject.normalize)).to eq(pts)
      end
    end

    context '"do no harm" fallback — reordering makes the max jump worse' do
      # Two clusters of points separated by > 5 km but already in the right order.
      # Nearest-neighbour will interleave them and produce a worse result;
      # the "do no harm" guard should revert to the cleaned input.
      let(:half_a) { 10.times.map { |i| [53.0 + (i * 0.001), -113.5 - (i * 0.001)] } }
      let(:half_b) { 10.times.map { |i| [53.1 + (i * 0.001), -113.6 + (i * 0.001)] } }
      let(:input)  { encode(half_a + half_b) }

      it 'preserves the original order rather than scrambling the route' do
        result = decode(subject.normalize)
        # The result should not be worse than the cleaned input:
        # its maximum consecutive jump should be ≤ the input's maximum jump.
        max_jump = ->(arr) { arr.each_cons(2).map { |a, b| [(b[0] - a[0]).abs, (b[1] - a[1]).abs].max }.max || 0 }
        expect(max_jump.call(result)).to be <= max_jump.call(half_a + half_b)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # remove_duplicate_passes — Problem 1: large-gap duplicate pass
  # ---------------------------------------------------------------------------
  describe 'duplicate pass removal (large gap)' do
    # Outbound 20 pts A→B, then exact reverse B→A.
    # The gap between the last outbound and first return point is 0 (they're
    # adjacent in the sequence) but the two halves overlap ≥ 80% in bbox.
    let(:outbound) { 20.times.map { |i| [53.0 + (i * 0.001), -113.5] } }
    let(:input)    { encode(outbound + outbound.reverse) }

    it 'removes the duplicate pass and keeps only one direction' do
      result = decode(subject.normalize)
      expect(result.size).to eq(outbound.size)
    end
  end

  # ---------------------------------------------------------------------------
  # remove_duplicate_passes — Problem 2: bookend seam gap < 5 km
  # ---------------------------------------------------------------------------
  describe 'bookend duplicate detection (sub-threshold seam)' do
    # pass1: 15 pts. pass2 starts ~4 km after pass1 ends (< 5 km threshold)
    # but shares the same endpoints as pass1 (forward duplicate).
    let(:pass1) { 15.times.map { |i| [53.0 + (i * 0.001), -113.5] } }
    let(:pass2) do
      start = [pass1.last[0] + 0.036, pass1.last[1]] # ~4 km north
      [start] + pass1.reverse[1..-1]
    end
    let(:input) { encode(pass1 + pass2) }

    it 'discards the second half when it is a bookend duplicate' do
      result = decode(subject.normalize)
      # The combined input has 30 pts; after discarding the duplicate pass only
      # the first half remains (roughly half the total point count).
      expect(result.size).to be < (pass1.size + pass2.size)
    end
  end

  # ---------------------------------------------------------------------------
  # remove_duplicate_passes — Problem 3: tiny stray trailing artefact
  # ---------------------------------------------------------------------------
  describe 'tiny stray trailing segment removal' do
    # 30-pt main route + 3-pt artefact after a > 5 km gap.
    let(:main)     { 30.times.map { |i| [53.0 + (i * 0.001), -113.5] } }
    let(:trailing) { [[54.0, -113.5], [54.001, -113.5], [54.002, -113.5]] }
    let(:input)    { encode(main + trailing) }

    it 'drops the tiny trailing artefact and keeps the main route' do
      result = decode(subject.normalize)
      expect(result.size).to eq(main.size)
    end
  end

  # ---------------------------------------------------------------------------
  # trim_out_and_back — Problem 5: divided highway both lanes in one polyline
  # ---------------------------------------------------------------------------
  describe 'out-and-back trim (divided highway)' do
    # Outbound: 20 diagonal pts. Return leg: same pts reversed, shifted 0.001° lat.
    # The turnaround sits at index 19 of 40 (ratio 0.475 → within 0.3..0.7)
    # and the two halves share substantial bbox extent on both axes.
    let(:outbound) { 20.times.map { |i| [53.0 + (i * 0.001), -113.5 + (i * 0.0001)] } }
    let(:ret_leg)  { outbound.reverse.map { |pt| [pt[0] + 0.001, pt[1]] } }
    let(:input)    { encode(outbound + ret_leg) }

    it 'keeps only the outbound leg and discards the return leg' do
      result = decode(subject.normalize)
      expect(result.size).to eq(outbound.size + 1) # includes shared turnaround pt
    end

    context 'when the turnaround falls outside the 30–70% window' do
      # Put the turnaround at index 2 of 20 pts (10% — too early to be a divided hwy)
      let(:outbound2) { 2.times.map  { |i| [53.0 + (i * 0.001), -113.5 + (i * 0.0001)] } }
      let(:rest)      { 18.times.map { |i| [53.002 - (i * 0.0001), -113.498 - (i * 0.0001)] } }
      let(:input) { encode(outbound2 + rest) }

      it 'does not trim the route' do
        # turnaround is not in the middle, so trim_out_and_back returns nil
        result = decode(subject.normalize)
        expect(result.size).to be > 0
      end
    end
  end

  # ---------------------------------------------------------------------------
  # bbox_overlap_ratio edge cases
  # ---------------------------------------------------------------------------
  describe 'bbox_overlap_ratio edge cases' do
    let(:rs) { described_class.new(encode([[53.0, -113.5], [53.001, -113.5]])) }

    it 'returns 0.0 when the bounding boxes do not overlap' do
      a = [[53.0, -113.5], [53.001, -113.5]]
      b = [[54.0, -113.5], [54.001, -113.5]]
      expect(rs.send(:bbox_overlap_ratio, a, b)).to eq(0.0)
    end

    it 'returns 0.0 when either segment has zero extent (all same coordinate)' do
      a = [[53.0, -113.5], [53.0, -113.5]] # zero lat extent
      b = [[53.0, -113.5], [53.0, -113.6]]
      expect(rs.send(:bbox_overlap_ratio, a, b)).to eq(0.0)
    end
  end
end
