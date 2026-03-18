# frozen_string_literal: true

RSpec.describe Feather::Instrumentation do
  describe ".instrument" do
    context "when ActiveSupport::Notifications is not available" do
      before { hide_const("ActiveSupport") if defined?(ActiveSupport) }

      it "yields the block" do
        yielded = false
        described_class.instrument("test.feather") { yielded = true }
        expect(yielded).to be(true)
      end

      it "returns the block's return value" do
        result = described_class.instrument("test.feather") { 42 }
        expect(result).to eq(42)
      end

      it "does not raise when payload is provided" do
        expect do
          described_class.instrument("test.feather", { foo: "bar" }) { :ok }
        end.not_to raise_error
      end
    end

    context "when ActiveSupport::Notifications is available" do
      let(:fake_notifications) do
        Module.new do
          @calls = []

          def self.instrument(name, payload = {}, &block)
            result = block.call
            @calls << { name: name, payload: payload.dup }
            result
          end

          class << self
            attr_reader :calls
          end

          def self.last_call
            @calls.last
          end
        end
      end

      before { stub_const("ActiveSupport::Notifications", fake_notifications) }

      it "delegates to ActiveSupport::Notifications.instrument" do
        described_class.instrument("identify.feather", { model: "claude-sonnet-4" }) { :ok }
        expect(ActiveSupport::Notifications.last_call[:name]).to eq("identify.feather")
      end

      it "passes the payload through" do
        described_class.instrument("identify.feather", { model: "claude-sonnet-4" }) { :ok }
        expect(ActiveSupport::Notifications.last_call[:payload]).to include(model: "claude-sonnet-4")
      end

      it "returns the block's return value" do
        result = described_class.instrument("identify.feather") { 99 }
        expect(result).to eq(99)
      end

      it "allows callers to mutate the payload inside the block" do
        payload = { model: "claude-sonnet-4" }
        described_class.instrument("identify.feather", payload) { payload[:result] = :bird }
        expect(payload[:result]).to eq(:bird)
      end
    end
  end
end
