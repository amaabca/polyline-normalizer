module Polyline
  module Normalizer
    class RoadSegment
      EARTHS_RADIUS = 6371e3   # meters
      DEGREES = Math::PI / 180 # degrees from radians

      attr_accessor(
        :input,
        :points,
        :distance_threshold
      )

      def initialize(input, distance_threshold: 5000)
        self.input = input
        self.distance_threshold = distance_threshold
        self.points = FastPolylines.decode(input).uniq
      end

      def normalize
        @normalize ||= FastPolylines.encode(join(divide))
      end

      private

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

      # naively sort the segments ascending by latitude (south to north)
      def join(parts)
        sort_index = sort_by_index
        parts
          .sort { |a, b| a.first[sort_index] <=> b.first[sort_index] }
          .each_with_object([]) { |s, acc| acc.push(*s) }
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

      # returns the "forward azimuth" or direction between two points
      # in degrees.
      # see: https://www.movable-type.co.uk/scripts/latlong.html#bearing
      def bearing(one, two)
        y = Math.sin(two[1] - one[1]) * Math.cos(two[0])
        x = Math.cos(one[0]) *
            Math.sin(two[0]) -
            Math.sin(one[0]) *
            Math.cos(two[0]) *
            Math.cos(two[1] - one[1])
        theta = Math.atan2(y, x)
        (theta * 180 / Math::PI + 360) % 360
      end

      # returns the geodesic distance between 2 lat/lon coordiantes in metres
      def geodesic_distance(one, two)
        # haversine formula for great-circle distance
        delta_lat = (two[0] - one[0]) * DEGREES
        delta_lon = (two[1] - one[1]) * DEGREES
        a = Math.sin(delta_lat / 2) ** 2 +
            Math.cos(one[0] * DEGREES) *
            Math.cos(two[0] * DEGREES) *
            Math.sin(delta_lon / 2) ** 2
        c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        c * EARTHS_RADIUS
      end
    end
  end
end
