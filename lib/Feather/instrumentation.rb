# frozen_string_literal: true

module Feather
  module Instrumentation
    def self.instrument(event_name, payload = {}, &)
      if defined?(ActiveSupport::Notifications)
        ActiveSupport::Notifications.instrument(event_name, payload, &)
      else
        yield
      end
    end
  end
end
