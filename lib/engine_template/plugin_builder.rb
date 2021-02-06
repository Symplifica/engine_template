#require "forwardable"

module EngineTemplate
  class PluginBuilder < Rails::PluginBuilder
    include EngineTemplate::Actions

    def add_gemfile_dependencies

      gem_group :test do
        gem 'rspec_junit_formatter', require: false
        gem 'simplecov-lcov', require: false
      end

      gem_group :development, :test do
        # Common
        gem 'byebug'
        gem 'factory_bot_rails'
        gem 'pry-rails'
        gem 'rspec-rails'
        gem 'shoulda-matchers'
        gem 'faker'

        # Code Quality
        gem 'rubocop'
        gem 'simplecov', require: false

        # Documentation
        gem 'annotate'
        gem 'yard'
      end
    end

    def add_dependencies_to_gemspec
      path_gemspec = "#{name}.gemspec"

      gsub_file path_gemspec, /spec.homepage    = "TODO"/, 'spec.homepage    = "https://symplifica.com"'
      gsub_file path_gemspec, /TODO: Summary of Testapp./, 'Symplifica Rails engine'
      gsub_file path_gemspec, /TODO: Description of Testapp./, 'Symplifica Rails engine'
      gsub_file path_gemspec, /TODO: Set to /, ''
      gsub_file path_gemspec, /TODO: Put your gem's public repo URL here./, 'https://symplifica.com'
      gsub_file path_gemspec, /TODO: Put your gem's CHANGELOG.md URL here./, 'https://symplifica.com'

      reference_inject_dependency = 'spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]'


      inject_into_file(path_gemspec, "\n\n  spec.add_dependency 'pg'", after: reference_inject_dependency)
      inject_into_file(path_gemspec, "\n\n  spec.add_dependency 'pagy'", after: reference_inject_dependency)


      inject_into_file(path_gemspec, "\n\n  spec.add_dependency 'searchkick'\n", after: reference_inject_dependency)
      inject_into_file(path_gemspec, "\n\n  spec.add_dependency 'gemoji-parser'\n", after: reference_inject_dependency)

    end

    def config_rspec
      template 'spec/rails_helper.rb'
      template 'spec/spec_helper.rb'
      inject_into_file(engine_class_path, "\n      g.test_framework :rspec", after: 'config.generators do |g|')
    end

    def config_factory_bot
      config = <<-RUBY

      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
      RUBY

      inject_into_file(engine_class_path, config, after: 'config.generators do |g|')
    end

    def load_dependencies
      config = <<-RUBY

    Gem.loaded_specs["#{name}"].dependencies.each do |dependence|
      require dependence.name
    end

      RUBY
      inject_into_class(engine_class_path, 'Engine', config)
    end

    def set_empty_generators
      generators = <<-RUBY

    config.generators do |g|
    end

      RUBY
      inject_into_class(engine_class_path, 'Engine', generators)
    end

    def config_webpacker
      template 'config/webpacker', 'config/webpacker.yml'
      directory 'config/webpack'
      template 'package.json'
      template 'babel.config.js'
      template 'postcss.config.js'

      inject_into_module("lib/#{namespaced_name}.rb", camelized_modules) do
        <<-RUBY
  ROOT_PATH = Pathname.new(File.join(__dir__, ".."))

  class << self
    def webpacker
      @webpacker ||= ::Webpacker::Instance.new(
        root_path: ROOT_PATH,
        config_path: ROOT_PATH.join("config/webpacker.yml")
      )
    end
  end
        RUBY
      end

      inject_into_class(engine_class_path, 'Engine') do
        <<-RUBY
    initializer "webpacker.proxy" do |app|
      insert_middleware = begin
                          #{camelized_modules}.webpacker.config.dev_server.present?
                        rescue
                          nil
                        end
      next unless insert_middleware

      app.middleware.insert_before(
        0, Webpacker::DevServerProxy, # "Webpacker::DevServerProxy" if Rails version < 5
        ssl_verify_none: true,
        webpacker: #{camelized_modules}.webpacker
      )
    end


    config.app_middleware.use(
      Rack::Static,
      urls: ["/#{webpacker_public_output_path}"], root: "#{namespaced_name}/public"
    )
        RUBY
      end

      inject_into_module("lib/#{namespaced_name}.rb", camelized_modules) do
        <<-RUBY
  ROOT_PATH = Pathname.new(File.join(__dir__, ".."))

  class << self
    def webpacker
      @webpacker ||= ::Webpacker::Instance.new(
        root_path: ROOT_PATH,
        config_path: ROOT_PATH.join("config/webpacker.yml")
      )
    end
  end
        RUBY
      end
      template 'app/helpers/%namespaced_name%/application_helper.rb.erb', 'app/helpers/%namespaced_name%/application_helper.rb', force: true
      template 'lib/tasks/webpacker_tasks.rake'
      template 'bin/webpack'
      template 'bin/webpack-dev-server'
      chmod "bin", 0755 & ~File.umask, verbose: false

      template 'app/javascript/packs/application.js'
      template 'app/javascript/packs/application.css'

      path_gitignore = "#{destination_root}/.gitignore"
      if File.exists?(path_gitignore)
        append_to_file path_gitignore do
            "\n"                   +
            "/public/packs\n"      +
            "/public/packs-test\n" +
            "/node_modules\n"      +
            "/yarn-error.log\n"    +
            "yarn-debug.log*\n"    +
            ".yarn-integrity\n"
        end
      end

      inside dummy_path do
        run 'rails webpacker:install'
      end

      say("Webpacker successfully installed in #{camelized_modules} Engine 🎉 🍰")
    end

    def config_annotate
      rails_command 'generate annotate:install'
    end

    def config_i18n
      template 'config/initializers/rails_i18n.rb'
    end
  end
end