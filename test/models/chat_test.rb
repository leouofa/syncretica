# frozen_string_literal: true

require "test_helper"

class ChatTest < ActiveSupport::TestCase
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

  test "create! resolves default configured ollama model from database" do
    chat = Chat.create!

    assert_not_nil chat.model
    assert_equal @model_id, chat.model.model_id
    assert_equal "ollama", chat.model.provider
  end

  test "to_llm initializes a RubyLLM::Chat targeting the configured ollama provider" do
    chat = Chat.create!
    llm_chat = chat.to_llm

    assert_equal @model_id, llm_chat.model.id
    assert_equal "ollama", llm_chat.model.provider
  end
end
