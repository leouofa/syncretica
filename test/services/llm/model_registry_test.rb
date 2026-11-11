# frozen_string_literal: true

require "test_helper"

module Llm
  class ModelRegistryTest < ActiveSupport::TestCase
    test "ensure_configured_model! registers the configured model idempotently" do
      model_id = "test-qwen-local"

      first = Llm::ModelRegistry.ensure_configured_model!(model_id: model_id)
      second = Llm::ModelRegistry.ensure_configured_model!(model_id: model_id)

      assert_equal first.id, second.id
      assert_equal "ollama", second.provider
      assert_equal model_id, second.model_id
      assert_equal Llm::ModelRegistry::DEFAULT_CONTEXT_WINDOW, second.context_window
      assert_not_nil RubyLLM.models.find_configured(model_id, provider: :ollama)
    end

    test "ensure_configured_model! returns nil when model_id is blank" do
      assert_nil Llm::ModelRegistry.ensure_configured_model!(model_id: "  ")
    end
  end
end
