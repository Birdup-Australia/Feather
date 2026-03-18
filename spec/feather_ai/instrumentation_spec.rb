# frozen_string_literal: true

RSpec.describe FeatherAi::Instrumentation do
  describe ".instrument" do
    context "when ActiveSupport::Notifications is not available" do
      before { hide_const("ActiveSupport") if defined?(ActiveSupport) }

      it "yields the block" do
        yielded = false
        described_class.instrument("test.feather_ai") { yielded = true }
        expect(yielded).to be(true)
      end

      it "returns the block's return value" do
        result = described_class.instrument("test.feather_ai") { 42 }
        expect(result).to eq(42)
      end

      it "does not raise when payload is provided" do
        expect do
          described_class.instrument("test.feather_ai", { foo: "bar" }) { :ok }
        end.not_to raise_error
      end
    end

    context "when ActiveSupport::Notifications is available" do
      let(:calls_tracker) { [] }

      let(:fake_notifications) do
        tracker = calls_tracker
        Module.new do
          define_singleton_method(:instrument) do |name, payload = {}, &block|
            result = block.call
            tracker << { name: name, payload: payload.dup }
            result
          end

          define_singleton_method(:calls) do
            tracker
          end

          define_singleton_method(:last_call) do
            tracker.last
          end
        end
      end

      before { stub_const("ActiveSupport::Notifications", fake_notifications) }

      it "delegates to ActiveSupport::Notifications.instrument" do
        described_class.instrument("identify.feather_ai", { model: "claude-sonnet-4" }) { :ok }
        expect(ActiveSupport::Notifications.last_call[:name]).to eq("identify.feather_ai")
      end

      it "passes the payload through" do
        described_class.instrument("identify.feather_ai", { model: "claude-sonnet-4" }) { :ok }
        expect(ActiveSupport::Notifications.last_call[:payload]).to include(model: "claude-sonnet-4")
      end

      it "returns the block's return value" do
        result = described_class.instrument("identify.feather_ai") { 99 }
        expect(result).to eq(99)
      end

      it "allows callers to mutate the payload inside the block" do
        payload = { model: "claude-sonnet-4" }
        described_class.instrument("identify.feather_ai", payload) { payload[:result] = :bird }
        expect(payload[:result]).to eq(:bird)
      end
    end
  end
end
