# frozen_string_literal: true

module Helpers
  module Fixtures
    PATH = Pathname.new(
      File.join(
        Gem.loaded_specs['polyline-normalizer'].full_gem_path,
        'spec',
        'fixtures'
      )
    ).freeze

    def read_fixture(*path)
      PATH.join(*path).read.chomp
    end
  end
end
