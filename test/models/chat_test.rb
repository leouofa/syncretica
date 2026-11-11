# frozen_string_literal: true

require "test_helper"

class ChatTest < ActiveSupport::TestCase
  setup do
    Llm::ModelRegistry.ensure_configured_model!
  end

  test "create! resolves default configured ollama model from database" do
    chat = Chat.create!

    assert_not_nil chat.model
    assert_equal ENV["OLLAMA_MODEL"], chat.model.model_id
    assert_equal "ollama", chat.model.provider
  end

  test "to_llm initializes a RubyLLM::Chat targeting the configured ollama provider" do
    chat = Chat.create!
    llm_chat = chat.to_llm

    assert_equal ENV["OLLAMA_MODEL"], llm_chat.model.id
    assert_equal "ollama", llm_chat.model.provider
  end
end
