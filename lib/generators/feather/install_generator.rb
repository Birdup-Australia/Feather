# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module Feather
  module Generators
    # Rails generator for installing Feather bird identification fields.
    class InstallGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Creates a migration to add bird identification fields to your sighting model"

      argument :model_name, type: :string, default: "sighting",
                            desc: "Name of the model to add sighting fields to"

      def self.next_migration_number(path)
        next_migration_number = current_migration_number(path) + 1
        ::ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def create_migration
        migration_template(
          "migration.rb.tt",
          "db/migrate/add_feather_fields_to_#{model_name.underscore.pluralize}.rb"
        )
      end
    end
  end
end
