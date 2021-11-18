module Polyline
  module Normalizer
    class Distance
      EARTHS_RADIUS = 6371e3   # meters
      DEGREES = Math::PI / 180 # degrees from radians

      class << self
        def normalize(input)
          points = heuristic_sort(FastPolylines.decode(input).uniq)
          start = points.pop
          path = [start]

          # O(n^2) - plus some overhead for removing from the center of an array
          while points.any?
            current = path.last
            min_index = points.size - 1
            min_distance = Float::INFINITY

            points.each_with_index do |point, index|
              distance = geodesic_distance(current, point)

              if distance < min_distance
                min_distance = distance
                min_index = index
              end
            end

            # remove the selected point from future consideration
            path.push(points.delete_at(min_index))
          end

          FastPolylines.encode(path)
        end

        private

        def heuristic_sort(points)
          start = points.first
          stop = points.last
          d_lat = (stop[0] - start[0]).abs
          d_lon = (stop[1] - start[1]).abs

          return points.sort { |a, b| b[0] <=> a[0] } if d_lat > d_lon

          points.sort { |a, b| b[1] <=> a[1] }
        end

        # returns the "forward azimuth" or direction between two points
        # in degrees.
        # see: https://www.movable-type.co.uk/scripts/latlong.html#bearing
        def heading(one, two)
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
end
