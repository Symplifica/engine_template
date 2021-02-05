module EngineTemplate
  RAILS_VERSION = '~> 6.1.1'.freeze
  RUBY_VERSION = IO
    .read("#{File.dirname(__FILE__)}/../../.ruby-version")
    .strip
    .freeze
  VERSION = '0.0.1'.freeze
end
