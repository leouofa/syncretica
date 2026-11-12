# frozen_string_literal: true

require "test_helper"

class DeepSynthesisReportAgentTest < ActiveSupport::TestCase
  setup do
    @previous_ollama_api_base = RubyLLM.config.ollama_api_base
    @previous_default_model = RubyLLM.config.default_model
    @model_id = ENV["OLLAMA_MODEL"].presence || "Qwen3.6-35B-A3B-NVFP4"

    RubyLLM.configure do |config|
      config.ollama_api_base = ENV["OLLAMA_API_BASE"].presence || "http://localhost:11434/v1"
      config.default_model = @model_id
    end

    Llm::ModelRegistry.ensure_configured_model!(model_id: @model_id)
  end

  teardown do
    RubyLLM.configure do |config|
      config.ollama_api_base = @previous_ollama_api_base
      config.default_model = @previous_default_model
    end
  end

  test "create! sets prompt instructions and aggregation digest correctly" do
    chat = DeepSynthesisReportAgent.create!(
      snapshot_title: "Myths Level 5",
      target_type: "Myth",
      level: 5,
      distance_threshold: 0.20,
      clusters_count: 10,
      items_count: 50,
      sub_report_digest: "### Batch #1 (covers 5 clusters)\nCross-pantheon trickster motifs."
    )

    assert chat.persisted?
    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "SNAPSHOT TITLE: Myths Level 5"
    assert_includes system_message.content, "Cross-pantheon trickster motifs."
    assert_includes system_message.content, "comparative mythologist"
  end
end
