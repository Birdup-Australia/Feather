# frozen_string_literal: true

module Feather
  module Rails
    module ActsAsSighting
      module ClassMethods
        def acts_as_sighting
          include InstanceMethods
        end
      end

      module InstanceMethods
        def identify!
          photo_file = photo.download
          result = Feather.identify(photo_file, location: location)

          update!(
            common_name: result.common_name,
            species: result.species,
            family: result.family,
            confidence: result.confidence.to_s,
            region_native: result.region_native?,
          )

          result
        ensure
          photo_file&.close! if photo_file.respond_to?(:close!)
        end
      end
    end
  end
end
