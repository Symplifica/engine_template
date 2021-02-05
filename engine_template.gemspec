$:.push File.expand_path('../lib', __FILE__)
require 'engine_template/version'
require 'date'

Gem::Specification.new do |s|
  s.required_ruby_version = ">= #{EngineTemplate::RUBY_VERSION}"
  s.required_rubygems_version = '>= 2.7.4'
  s.authors = ['Diego Orejuela']
  s.date = Date.today.strftime('%Y-%m-%d')

  s.description = <<~HERE
    Engine template is a base Rails Engine project that you can upgrade. It is used by
    symplifica to get a jump start on a working app.
  HERE

  s.email = 'support@symplifica.com'
  s.executables = ['engine_template']
  s.extra_rdoc_files = %w[README.md LICENSE]
  s.files = `git ls-files`.split("\n")
  s.homepage = 'http://github.com/symplifica/engine_template'
  s.license = 'MIT'
  s.name = 'engine_template'
  s.rdoc_options = ['--charset=UTF-8']
  s.require_paths = ['lib']
  s.summary = "Generate a Rails app using symplifica's best practices."
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.version = EngineTemplate::VERSION

  s.add_dependency 'bitters', '>= 2.0.4'
  s.add_dependency 'rails', EngineTemplate::RAILS_VERSION

  s.add_development_dependency 'rspec', '~> 3.2'
  s.add_development_dependency 'standard'
end
