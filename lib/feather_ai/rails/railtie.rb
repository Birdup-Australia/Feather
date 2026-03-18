# frozen_string_literal: true

module FeatherAi
  module Rails
    # Rails integration via Railtie.
    class Railtie < ::Rails::Railtie
      initializer "feather_ai.acts_as_sighting" do
        ActiveSupport.on_load(:active_record) do
          extend FeatherAi::Rails::ActsAsSighting::ClassMethods
        end
      end
    end
  end
end
