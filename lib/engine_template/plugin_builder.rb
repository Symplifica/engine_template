#require "forwardable"

module EngineTemplate
  class PluginBuilder < Rails::PluginBuilder
    include EngineTemplate::Actions
    #extend Forwardable

    # def_delegators(
    #   :heroku_adapter,
    #   :create_heroku_pipeline,
    #   :create_production_heroku_app,
    #   :create_staging_heroku_app,
    #   :set_heroku_application_host,
    #   :set_heroku_backup_schedule,
    #   :set_heroku_honeybadger_env,
    #   :set_heroku_rails_secrets,
    #   :set_heroku_remotes,
    #   :set_heroku_buildpacks
    # )

    # Overwrite
    # def gemfile
    #   say 'Get template Gemfile'
    #   template 'Gemfile.erb', 'Gemfile'
    # end

    # Overwrite
    # def gemspec
    #   say local_variables
    #   @database = 'pg'
    #   template "template.gemspec"
    # end
    #
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

      # if yes?('Add searckick?')
      #   inject_into_file(path_gemspec, "\n\n  spec.add_dependency 'searchkick'\n", after: reference_inject_dependency)
      #   inject_into_file(path_gemspec, "\n\n  spec.add_dependency 'gemoji-parser'\n", after: reference_inject_dependency)
      # end
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

    # def readme
    #   template "README.md.erb", "README.md"
    # end
    #
    # def gitignore
    #   copy_file "suspenders_gitignore", ".gitignore"
    # end
    #
    # def gemfile
    #   template "Gemfile.erb", "Gemfile"
    # end

    # def setup_rack_mini_profiler
    #   copy_file(
    #     "rack_mini_profiler.rb",
    #     "config/initializers/rack_mini_profiler.rb"
    #   )
    # end
    #
    # def raise_on_missing_assets_in_test
    #   configure_environment "test", "config.assets.raise_runtime_errors = true"
    # end
    #
    # def raise_on_delivery_errors
    #   replace_in_file "config/environments/development.rb",
    #     "raise_delivery_errors = false", "raise_delivery_errors = true"
    # end
    #
    # def set_test_delivery_method
    #   inject_into_file(
    #     "config/environments/development.rb",
    #     "\n  config.action_mailer.delivery_method = :file",
    #     after: "config.action_mailer.raise_delivery_errors = true"
    #   )
    # end
    #
    # def raise_on_unpermitted_parameters
    #   config = <<-RUBY
    # config.action_controller.action_on_unpermitted_parameters = :raise
    #   RUBY
    #
    #   inject_into_class "config/application.rb", "Application", config
    # end
    #
    # def configure_quiet_assets
    #   config = <<-RUBY
    # config.assets.quiet = true
    #   RUBY
    #
    #   inject_into_class "config/application.rb", "Application", config
    # end
    #
    # def provide_setup_script
    #   template "bin_setup", "bin/setup", force: true
    #   run "chmod a+x bin/setup"
    # end
    #
    # def configure_generators
    #   config = <<-RUBY
    #
    # config.generators do |generate|
    #   generate.helper false
    #   generate.javascripts false
    #   generate.request_specs false
    #   generate.routing_specs false
    #   generate.stylesheets false
    #   generate.test_framework :rspec
    #   generate.view_specs false
    # end
    #
    #   RUBY
    #
    #   inject_into_class "config/application.rb", "Application", config
    # end
    #
    # def configure_local_mail
    #   copy_file "email.rb", "config/initializers/email.rb"
    # end
    #
    # def setup_asset_host
    #   replace_in_file "config/environments/production.rb",
    #     "# config.action_controller.asset_host = 'http://assets.example.com'",
    #     'config.action_controller.asset_host = ENV.fetch("ASSET_HOST", ENV.fetch("APPLICATION_HOST"))'
    #
    #   if File.exist?("config/initializers/assets.rb")
    #     replace_in_file "config/initializers/assets.rb",
    #       "config.assets.version = '1.0'",
    #       'config.assets.version = (ENV["ASSETS_VERSION"] || "1.0")'
    #   end
    #
    #   config = <<~EOD
    #     config.public_file_server.headers = {
    #         "Cache-Control" => "public, max-age=31557600",
    #       }
    #   EOD
    #
    #   configure_environment("production", config)
    # end
    #
    # def setup_secret_token
    #   template "secrets.yml", "config/secrets.yml", force: true
    # end
    #
    # def disallow_wrapping_parameters
    #   remove_file "config/initializers/wrap_parameters.rb"
    # end
    #
    # def use_postgres_config_template
    #   template "postgresql_database.yml.erb", "config/database.yml",
    #     force: true
    # end
    #
    # def create_database
    #   bundle_command "exec rails db:create db:migrate"
    # end
    #
    # def replace_gemfile(path)
    #   template "Gemfile.erb", "Gemfile", force: true do |content|
    #     if path
    #       content.gsub(%r{gem .suspenders.}) { |s| %(#{s}, path: "#{path}") }
    #     else
    #       content
    #     end
    #   end
    # end
    #
    # def ruby_version
    #   create_file ".ruby-version", "#{Suspenders::RUBY_VERSION}\n"
    # end
    #
    # def configure_i18n_for_missing_translations
    #   raise_on_missing_translations_in("development")
    #   raise_on_missing_translations_in("test")
    # end
    #
    # def configure_action_mailer_in_specs
    #   copy_file "action_mailer.rb", "spec/support/action_mailer.rb"
    # end
    #
    # def configure_time_formats
    #   remove_file "config/locales/en.yml"
    #   template "config_locales_en.yml.erb", "config/locales/en.yml"
    # end
    #
    # def configure_action_mailer
    #   action_mailer_host "development", %("localhost:3000")
    #   action_mailer_asset_host "development", %("http://localhost:3000")
    #   action_mailer_host "test", %("www.example.com")
    #   action_mailer_asset_host "test", %("http://www.example.com")
    #   action_mailer_host "production", %{ENV.fetch("APPLICATION_HOST")}
    #   action_mailer_asset_host(
    #     "production",
    #     %{ENV.fetch("ASSET_HOST", ENV.fetch("APPLICATION_HOST"))}
    #   )
    # end
    #
    # def create_heroku_apps(flags)
    #   create_staging_heroku_app(flags)
    #   create_production_heroku_app(flags)
    # end
    #
    # def configure_automatic_deployment
    #   append_file "Procfile", "release: bin/auto_migrate\n"
    #   copy_file "bin_auto_migrate", "bin/auto_migrate"
    # end
    #
    # def create_github_repo(repo_name)
    #   run "hub create #{repo_name}"
    # end
    #
    # def copy_miscellaneous_files
    #   copy_file "errors.rb", "config/initializers/errors.rb"
    #   copy_file "json_encoding.rb", "config/initializers/json_encoding.rb"
    # end
    #
    # def remove_config_comment_lines
    #   config_files = [
    #     "application.rb",
    #     "environment.rb",
    #     "environments/development.rb",
    #     "environments/production.rb",
    #     "environments/test.rb"
    #   ]
    #
    #   config_files.each do |config_file|
    #     path = File.join(destination_root, "config/#{config_file}")
    #
    #     accepted_content = File.readlines(path).reject { |line|
    #       line =~ /^.*#.*$/ || line =~ /^$\n/
    #     }
    #
    #     File.open(path, "w") do |file|
    #       accepted_content.each { |line| file.puts line }
    #     end
    #   end
    # end
    #
    # def remove_routes_comment_lines
    #   replace_in_file "config/routes.rb",
    #     /Rails\.application\.routes\.draw do.*end/m,
    #     "Rails.application.routes.draw do\nend"
    # end
    #
    # def setup_default_rake_task
    #   append_file "Rakefile" do
    #     <<~EOS
    #       task(:default).clear
    #       task default: [:spec]
    #
    #       if defined? RSpec
    #         task(:spec).clear
    #         RSpec::Core::RakeTask.new(:spec) do |t|
    #           t.verbose = false
    #         end
    #       end
    #     EOS
    #   end
    # end
    #
    # private
    #
    # def raise_on_missing_translations_in(environment)
    #   config = "config.action_view.raise_on_missing_translations = true"
    #
    #   uncomment_lines("config/environments/#{environment}.rb", config)
    # end
    #
    # def heroku_adapter
    #   @heroku_adapter ||= Adapters::Heroku.new(self)
    # end
  end
end