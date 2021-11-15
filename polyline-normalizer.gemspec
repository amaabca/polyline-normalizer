# frozen_string_literal: true

require_relative 'lib/polyline/normalizer/version'

Gem::Specification.new do |spec|
  spec.name = 'polyline-normalizer'
  spec.version = Polyline::Normalizer::VERSION
  spec.authors = [
    'Jesse Doyle',
    'Michael van den Beuken',
    'Darko Dosenovic',
    'Zoie Carnegie'
  ]
  spec.email = [
    'jesse.doyle@ama.ab.ca',
    'michael.vandenbeuken@ama.ab.ca',
    'darko.dosenovic@ama.ab.ca',
    'zoie.carnegie@ama.ab.ca'
  ]
  spec.summary = 'Normalize paths encoded with the Google Polyline Algorithm'
  spec.description = <<~SUMMARY
    Sort and scale the points of a path encoded with the Google Polyline
    Algorithm by distance to one another.
  SUMMARY
  spec.homepage = 'https://github.com/amaabca/polyline-normalizer'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.3.0')
  spec.metadata['allowed_push_host'] = 'https://rubygems.org/'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`
      .split("\x0")
      .reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
