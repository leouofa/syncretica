# frozen_string_literal: true

require "test_helper"

class PantheonDiscoveryAgentTest < ActiveSupport::TestCase
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

  test "create! configures schema and includes existing names in system instructions" do
    chat = PantheonDiscoveryAgent.create!(existing_names: [ "Greek", "Norse" ])

    assert chat.persisted?
    system_message = chat.messages.find_by!(role: "system")
    assert_includes system_message.content, "Greek, Norse"
    assert_includes system_message.content, "comparative mythology scholar"

    schema_props = chat.schema.dig(:schema, :properties) || chat.schema[:properties]
    assert_not_nil schema_props
    assert_includes schema_props.keys, :pantheons
  end
end
