# frozen_string_literal: true

require "test_helper"

class ClusterGroupSummaryAgentTest < ActiveSupport::TestCase
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

  test "create! sets prompt instructions and untruncated member detail correctly" do
    chat = ClusterGroupSummaryAgent.create!(
      report_prompt: "Find patterns in trickster deities",
      snapshot_title: "Gods Snapshot",
      target_type: "God",
      cluster_rank: 1,
      total_clusters: 10,
      cluster_name: "Trickery and Boundary Crossing",
      cluster_size: 4,
      shared_themes: [ "trickery", "cunning" ],
      cluster_members_detail: "[1] Loki (Norse)\n[2] Hermes (Greek)\n[3] Anansi (Ashanti)"
    )

    assert chat.persisted?
    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Find patterns in trickster deities"
    assert_includes system_message.content, "Trickery and Boundary Crossing"
    assert_includes system_message.content, "[1] Loki (Norse)"
  end
end
