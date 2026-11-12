# frozen_string_literal: true

require "test_helper"

class ModelRegistryTest < ActiveSupport::TestCase
  test "current_context_window returns default when not set" do
    window = Llm::ModelRegistry.current_context_window(model_id: "non-existent-model")
    assert_operator window, :>=, 4096
  end

  test "update_context_window! updates model record and changes digest budget" do
    model_id = "test-model-#{SecureRandom.hex(4)}"
    record = Llm::ModelRegistry.ensure_configured_model!(model_id: model_id)
    assert_not_nil record

    Llm::ModelRegistry.update_context_window!(131_072, model_id: model_id)
    assert_equal 131_072, Llm::ModelRegistry.current_context_window(model_id: model_id)

    budget = Llm::ModelRegistry.digest_char_budget
    assert_operator budget, :>=, 30_000
  end

  test "update_context_window! raises on small token count" do
    assert_raises(ArgumentError) do
      Llm::ModelRegistry.update_context_window!(100, model_id: "some-model")
    end
  end
end
