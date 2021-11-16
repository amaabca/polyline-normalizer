module Helpers
  module Fixtures
    PATH = File.join(
      Gem.loaded_specs['polyline-normalizer'].full_gem_path,
      'spec',
      'fixtures'
    ).freeze

    def read_fixture(*path)
      File.read(File.join(PATH, *path)).chomp
    end
  end
end
