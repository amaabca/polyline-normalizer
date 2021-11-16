module Polyline
  module Normalizer
    class Distance
      ATTRIBUTES = [
        :reduction_factor
      ].freeze

      attr_accessor(:reduction_factor)

      def initialize(reduction_factor: 1)
        self.reduction_factor = reduction_factor
      end

      def normalize(input)
        # O(n) - reduces the input size for a more complex algorithm later
        points = FastPolylines.decode(input)
        points
          .keep_if
          .with_index { |_, i| i % reduction_factor == 0 }
        path = [points.pop]

        # O(n^2) - plus some overhead for removing from the center of an array
        while points.any?
          current = path.last
          min_index = points.size - 1
          min_distance = Float::INFINITY

          points.each_with_index do |point, index|
            # distance - pythagorean theorem
            distance = Math.sqrt(
              ((current[0] - point[0]) ** 2) +
              ((current[1] - point[1]) ** 2)
            )

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
    end
  end
end
