# frozen_string_literal: true

require "test_helper"

class RubyLlmConfigTest < ActiveSupport::TestCase
  test "configures ollama_api_base and default_model from ENV" do
    assert_equal ENV["OLLAMA_API_BASE"], RubyLLM.config.ollama_api_base
    assert_equal ENV["OLLAMA_MODEL"], RubyLLM.config.default_model
  end
end
