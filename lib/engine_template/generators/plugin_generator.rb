require 'rails/generators'
require 'rails/generators/rails/plugin/plugin_generator'

module EngineTemplate
  class PluginGenerator < Rails::Generators::PluginGenerator

    class_option :database, type: :string, aliases: '-d', default: 'postgresql',
                            desc: "Configure for selected database (options: #{DATABASES.join("/")})"

    class_option :version, type: :boolean, aliases: '-v', group: :engine_template,
                           desc: 'Show Suspenders version number and quit'

    class_option :help, type: :boolean, aliases: '-h', group: :engine_template,
                        desc: 'Show this help message and quit'

    # class_option :skip_test, type: :boolean, default: true,
    #                          desc: "Skip Test Unit"

    # class_option :skip_system_test,
    #   type: :boolean, default: true, desc: "Skip system test files"

    # class_option :skip_turbolinks,
    #   type: :boolean, default: true, desc: "Skip turbolinks gem"

    attr_accessor :database

    def finish_template
      invoke :engine_template_customization
      super
    end


    def engine_template_customization
      invoke :add_main_gems
      build :set_empty_generators
      build :add_gemfile_dependencies
      build :add_dependencies_to_gemspec
      run 'bundle install'
      build :config_rspec
      build :config_factory_bot
      build :config_webpacker if mountable?
      build :load_dependencies
      run 'yarn install'
      # rake "db:create"
      # rake "db:migrate"

      # rails_command "db:migrate"
    end

    def add_main_gems
      gem 'puma'
      gem 'webpacker'
    end

    def engine_class_path
      "lib/#{namespaced_name}/engine.rb"
    end

    def webpacker_dev_server_prefix
      "#{namespaced_name.upcase}_WEBPACKER_DEV_SERVER"
    end

    def webpacker_public_output_path
      "#{namespaced_name.gsub('_', '-')}-packs"
    end

    protected

    def get_builder_class
      EngineTemplate::PluginBuilder
    end
  end
end
