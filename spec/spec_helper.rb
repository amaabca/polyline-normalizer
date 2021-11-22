# frozen_string_literal: true

require 'simplecov'
require 'pry'
require 'polyline/normalizer'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.include(Helpers::Fixtures)
  config.example_status_persistence_file_path = '.rspec_status'
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
