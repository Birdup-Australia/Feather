# frozen_string_literal: true

module Feather
  module Rails
    module ActsAsSighting
      CORRECTABLE_FIELDS = %i[common_name species family confidence region_native].freeze

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
            region_native: result.region_native?
          )

          result
        ensure
          photo_file&.close! if photo_file.respond_to?(:close!)
        end

        def correct!(attrs)
          return if attrs.empty?

          invalid_keys = attrs.keys.map(&:to_sym) - CORRECTABLE_FIELDS
          unless invalid_keys.empty?
            raise ArgumentError,
                  "Unknown correctable field(s): #{invalid_keys.join(", ")}. " \
                  "Allowed fields: #{CORRECTABLE_FIELDS.join(", ")}"
          end

          corrected_attrs = attrs.each_with_object({}) do |(field, value), hash|
            hash[:"corrected_#{field}"] = value
          end

          update!(corrected_attrs.merge(corrected_at: Time.current))
        end

        def corrected?
          !corrected_at.nil?
        end

        def correction_delta
          return {} unless corrected?

          CORRECTABLE_FIELDS.each_with_object({}) do |field, delta|
            corrected_value = public_send(:"corrected_#{field}")
            next if corrected_value.nil?

            # NOTE: `public_send(field)` reads the original AI column, not the
            # corrected column, so :from always reflects the AI identification
            # regardless of how many times correct! has been called.
            delta[field] = { from: public_send(field), to: corrected_value }
          end
        end
      end
    end
  end
end
