# frozen_string_literal: true

module Feather
  module Rails
    module ActsAsSighting
      CORRECTABLE_FIELDS = %i[common_name species family confidence region_native].freeze

      # Class methods for ActiveRecord models.
      module ClassMethods
        def acts_as_sighting
          include InstanceMethods
        end
      end

      # Instance methods for bird sighting records.
      module InstanceMethods
        def identify!
          photo_file = photo.download
          result = Feather.identify(photo_file, location: location)
          update_from_result!(result)
          result
        ensure
          close_photo_file(photo_file)
        end

        def correct!(attrs)
          return if attrs.empty?

          validate_correctable_fields!(attrs.keys)
          update!(prefix_and_timestamp_attrs(attrs))
        end

        private

        def update_from_result!(result)
          update!(
            common_name: result.common_name,
            species: result.species,
            family: result.family,
            confidence: result.confidence.to_s,
            region_native: result.region_native?
          )
        end

        def close_photo_file(photo_file)
          photo_file&.close! if photo_file.respond_to?(:close!)
        end

        def validate_correctable_fields!(keys)
          invalid_keys = keys.map(&:to_sym) - CORRECTABLE_FIELDS
          return if invalid_keys.empty?

          raise ArgumentError,
                "Unknown correctable field(s): #{invalid_keys.join(", ")}. " \
                "Allowed fields: #{CORRECTABLE_FIELDS.join(", ")}"
        end

        def prefix_and_timestamp_attrs(attrs)
          corrected_attrs = attrs.each_with_object({}) do |(field, value), hash|
            hash[:"corrected_#{field}"] = value
          end
          corrected_attrs.merge(corrected_at: Time.current)
        end

        public

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
