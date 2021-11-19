module Polyline
  module Normalizer
    class Distance
      EARTHS_RADIUS = 6371e3   # meters
      DEGREES = Math::PI / 180 # degrees from radians

      class << self
        def normalize(input, threshold = 5000)
          points = FastPolylines.decode(input).uniq
          segments = divide(points, threshold)
          path = join(segments)
          FastPolylines.encode(path)
        end

        private

        # naively sort the segments ascending by latitude (south to north)
        def join(segments)
          segments
            .sort { |a, b| a.first[0] <=> b.first[0] }
            .each_with_object([]) { |s, acc| acc.push(*s) }
        end

        def divide(points, threshold)
          path = [points.pop]
          segments = [path]

          while points.any?
            current = path.last
            min_index = -1
            min_distance = Float::INFINITY

            points.each_with_index do |point, index|
              distance = geodesic_distance(current, point)
              if distance < min_distance
                min_distance = distance
                min_index = index
              end
            end

            if min_distance > threshold
              # new segment
              path = [points.delete_at(min_index)]
              segments << path
            else
              path.push(points.delete_at(min_index))
            end
          end

          segments
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
