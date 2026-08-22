# frozen_string_literal: true

module Polyline
  module Normalizer
    class RoadSegment
      EARTHS_RADIUS = 6_371_000.to_f # meters
      DEGREES_TO_RADIANS = Math::PI / 180

      attr_accessor(
        :input,
        :points,
        :distance_threshold
      )

      def initialize(input, distance_threshold: 5000)
        self.input = input
        self.distance_threshold = distance_threshold
        raw = FastPolylines.decode(input).uniq
        self.points = remove_duplicate_passes(raw)
      end

      def normalize
        # If the cleaned input has no gaps exceeding the threshold, the route is
        # already correctly ordered — sorting by a single axis would scramble
        # curved or arc-shaped roads. Return the re-encoded cleaned input as-is.
        return @normalize ||= encode_utf8(points) unless needs_reorder?

        reordered = FastPolylines.encode(join(divide))

        # "Do no harm": if reordering made the max jump worse (e.g. a correctly-
        # encoded route with a legitimate gap was scrambled by axis-sorting),
        # fall back to the cleaned but unsorted input.
        @normalize ||= if max_jump(FastPolylines.decode(reordered)) > max_jump(points)
                         encode_utf8(points)
                       else
                         reordered.force_encoding('UTF-8')
                       end
      end

      private

      # Perform a basic heuristic to determine what we should sort by (either
      # the lat or the lon coordinate).
      #
      # If the difference between the latitudes of the start/end point is
      # greater than the difference of the longitudes of the start/end point,
      # then sort by latitude (south to north). Otherwise sort by longitude
      # (east to west).
      def sort_by_index
        start = points.first
        stop = points.last
        d_lat = (stop[0] - start[0]).abs
        d_lon = (stop[1] - start[1]).abs

        if d_lat > d_lon
          0
        else
          1
        end
      end

      def join(parts)
        sort_index = sort_by_index
        parts
          .sort { |a, b| a.first[sort_index] <=> b.first[sort_index] }
          .each_with_object([]) { |s, acc| acc.push(*s) }
      end

      def encode_utf8(pts)
        FastPolylines.encode(pts).force_encoding('UTF-8')
      end

      # Returns true when the cleaned point sequence contains at least one gap
      # larger than +distance_threshold+, indicating the points need reordering.
      # Routes with no such gaps are already correctly ordered and should not be
      # sorted, as sorting by a single axis scrambles curved or arc-shaped roads.
      def needs_reorder?
        points.each_cons(2).any? do |a, b|
          geodesic_distance(a, b) > distance_threshold
        end
      end

      # Returns the maximum consecutive jump (in degrees, max of dlat/dlon) for
      # a set of points. Used to compare input and output quality.
      def max_jump(pts)
        pts.each_cons(2).map do |a, b|
          [(b[0] - a[0]).abs, (b[1] - a[1]).abs].max
        end.max || 0
      end

      # Split the raw point sequence into natural segments (wherever
      # consecutive points are farther apart than +distance_threshold+), then
      # discard any segment whose geographic bounding box substantially
      # overlaps one already kept. This removes cases where the upstream
      # source encodes the same route twice in a single polyline.
      #
      # Additionally, tiny trailing/leading sub-segments (< 5% of total points
      # or < 10 points) are dropped unconditionally. These are data artefacts
      # that cause +needs_reorder?+ to fire on an otherwise correctly-ordered
      # route, leading the nearest-neighbour algorithm to scramble valid data.
      #
      # Deduplication must happen on the raw sequence *before* the
      # nearest-neighbour traversal in +divide+, because the two near-identical
      # passes are close enough (~100 m) that nearest-neighbour would
      # interleave them into a single segment, hiding the duplication.
      def remove_duplicate_passes(pts, overlap_threshold: 0.8)
        return pts if pts.size < 2

        natural_segments = split_at_gaps(pts)
        min_size = [pts.size * 0.05, 10].max.to_i
        natural_segments.reject! { |s| s.size < min_size }
        natural_segments = apply_bookend_check(pts, natural_segments)
        natural_segments.map! { |s| trim_out_and_back(s) || s }
        deduplicate_by_bbox(natural_segments, overlap_threshold)
      end

      # Splits +pts+ into sub-arrays wherever consecutive points exceed
      # +distance_threshold+. Returns an array of sub-arrays (natural segments).
      def split_at_gaps(pts)
        natural_segments = []
        current = [pts.first]
        pts.each_cons(2) do |a, b|
          if geodesic_distance(a, b) > distance_threshold
            natural_segments << current
            current = [b]
          else
            current << b
          end
        end
        natural_segments << current
      end

      # When only one natural segment exists, checks whether the largest
      # internal gap (> 3 km) is a "bookend duplicate" — both halves share
      # the same start/end endpoints — and discards the second half if so.
      def apply_bookend_check(pts, natural_segments)
        return natural_segments unless natural_segments.size == 1

        max_gap_idx = pts.each_cons(2).with_index
                         .max_by { |(a, b), _| geodesic_distance(a, b) }
                         &.last
        return natural_segments unless max_gap_idx

        max_gap_dist = geodesic_distance(pts[max_gap_idx], pts[max_gap_idx + 1])
        return natural_segments unless max_gap_dist > 3000

        first_half  = pts[0..max_gap_idx]
        second_half = pts[(max_gap_idx + 1)..-1]
        bookend_duplicate?(first_half, second_half) ? [first_half] : natural_segments
      end

      # Keeps only the first segment from +segments+ when a later candidate's
      # bounding box overlaps a kept segment's bbox by at least +overlap_threshold+.
      def deduplicate_by_bbox(segments, overlap_threshold)
        kept = []
        segments.each do |candidate|
          next if kept.any? { |k| overlapping_segments?(k, candidate, overlap_threshold) }

          kept << candidate
        end
        kept.flatten(1)
      end

      # Detects a divided-highway out-and-back encoding: a single point sequence
      # that travels from A → B then immediately returns B → A along the other
      # lane. The turnaround point is the point farthest from the start. If the
      # turnaround sits within the middle 40% of the sequence (30–70%) AND the
      # outbound and return halves share ≥ 70% of their bounding box extent on
      # both axes, the sequence is divided-highway encoded and only the outbound
      # half is returned. Returns nil if the pattern is not detected.
      def trim_out_and_back(pts, turnaround_ratio_range: (0.3..0.7), overlap_threshold: 0.7)
        return nil if pts.size < 10

        start_pt = pts.first
        turnaround_idx = pts.each_with_index.max_by { |pt, _i| geodesic_distance(start_pt, pt) }[1]
        ratio = turnaround_idx.to_f / pts.size
        return nil unless turnaround_ratio_range.cover?(ratio)

        outbound   = pts[0..turnaround_idx]
        return_leg = pts[turnaround_idx..-1]

        return nil unless bbox_overlap_ratio(outbound, return_leg) >= overlap_threshold

        outbound
      end

      # Minimum bbox overlap ratio of two point arrays across both lat and lon axes.
      def bbox_overlap_ratio(pts_a, pts_b)
        [
          axis_overlap_ratio(pts_a.map(&:first), pts_b.map(&:first)),
          axis_overlap_ratio(pts_a.map(&:last),  pts_b.map(&:last))
        ].min
      end

      # Fraction of the smaller range's extent shared by arr_a and arr_b on one axis.
      def axis_overlap_ratio(arr_a, arr_b)
        overlap = [arr_a.max, arr_b.max].min - [arr_a.min, arr_b.min].max
        return 0.0 if overlap <= 0

        smaller = [arr_a.max - arr_a.min, arr_b.max - arr_b.min].min
        return 0.0 if smaller <= 0

        overlap / smaller
      end

      # Returns true when +second+ is a duplicate forward or reverse pass of
      # +first+, identified by the endpoints of +second+ landing within
      # +proximity+ metres of the start/end of +first+.
      def bookend_duplicate?(first, second, proximity: 200)
        # Forward duplicate: second starts near first's start AND ends near first's end
        forward = geodesic_distance(second.first, first.first) <= proximity &&
                  geodesic_distance(second.last,  first.last)  <= proximity
        # Reverse duplicate: second starts near first's end AND ends near first's start
        reverse = geodesic_distance(second.first, first.last)  <= proximity &&
                  geodesic_distance(second.last,  first.first) <= proximity
        forward || reverse
      end

      # Returns true when the bounding boxes of +a+ and +b+ overlap by at
      # least +threshold+ of the smaller segment's extent on both lat and lon.
      def overlapping_segments?(seg_a, seg_b, threshold)
        a_lats = seg_a.map(&:first)
        b_lats = seg_b.map(&:first)
        a_lons = seg_a.map(&:last)
        b_lons = seg_b.map(&:last)

        range_overlap_ratio(a_lats.min, a_lats.max, b_lats.min, b_lats.max) >= threshold &&
          range_overlap_ratio(a_lons.min, a_lons.max, b_lons.min, b_lons.max) >= threshold
      end

      # Fraction of the smaller range's extent that the two ranges share.
      # Returns 0.0 when the ranges do not overlap.
      def range_overlap_ratio(a_min, a_max, b_min, b_max)
        overlap = [a_max, b_max].min - [a_min, b_min].max
        return 0.0 if overlap <= 0

        smaller_extent = [a_max - a_min, b_max - b_min].min
        return 0.0 if smaller_extent <= 0

        overlap / smaller_extent
      end

      def divide
        unvisited_nodes = points.dup
        path = [unvisited_nodes.pop]
        segments = [path]

        while unvisited_nodes.any?
          current = path.last
          min_index = -1
          min_distance = Float::INFINITY

          unvisited_nodes.each_with_index do |point, index|
            distance = geodesic_distance(current, point)

            if distance < min_distance
              min_distance = distance
              min_index = index
            end
          end

          if min_distance > distance_threshold
            # new segment
            path = [unvisited_nodes.delete_at(min_index)]
            segments << path
          else
            path.push(unvisited_nodes.delete_at(min_index))
          end
        end

        segments
      end

      # returns the geodesic distance between 2 lat/lon coordinates in metres
      # calculated from the haversine formula for great-circle distance
      def geodesic_distance(one, two)
        # first make sure all of our inputs are in radians
        delta_lat = (two[0] - one[0]) * DEGREES_TO_RADIANS
        delta_lon = (two[1] - one[1]) * DEGREES_TO_RADIANS
        lat_one = one[0] * DEGREES_TO_RADIANS
        lat_two = two[0] * DEGREES_TO_RADIANS

        # haversine formula
        a = (Math.sin(delta_lat / 2)**2) +
            ((Math.sin(delta_lon / 2)**2) *
            Math.cos(lat_one) * Math.cos(lat_two))
        c = 2 * Math.asin(Math.sqrt(a))
        c * EARTHS_RADIUS
      end
    end
  end
end
