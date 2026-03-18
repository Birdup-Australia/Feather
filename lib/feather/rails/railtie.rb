# frozen_string_literal: true

module Feather
  module Rails
    # Rails integration via Railtie.
    class Railtie < ::Rails::Railtie
      initializer "feather.acts_as_sighting" do
        ActiveSupport.on_load(:active_record) do
          extend Feather::Rails::ActsAsSighting::ClassMethods
        end
      end
    end
  end
end
