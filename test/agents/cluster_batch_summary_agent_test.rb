# frozen_string_literal: true

require "test_helper"

class ClusterBatchSummaryAgentTest < ActiveSupport::TestCase
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

  test "create! sets prompt instructions and batch context correctly" do
    chat = ClusterBatchSummaryAgent.create!(
      report_prompt: "Find patterns in trickster deities",
      snapshot_title: "Gods Snapshot",
      target_type: "God",
      batch_index: 2,
      total_batches: 4,
      cluster_count: 3,
      batch_digest: "--- Cluster #4: \"Trickery\" (3 members) ---\nLoki, Hermes, Anansi"
    )

    assert chat.persisted?
    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Find patterns in trickster deities"
    assert_includes system_message.content, "batch #2 of 4"
    assert_includes system_message.content, "3 archetype clusters"
    assert_includes system_message.content, "Loki, Hermes, Anansi"
  end
end
