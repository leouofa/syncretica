# frozen_string_literal: true

require "test_helper"

class RubyLlmConfigTest < ActiveSupport::TestCase
  test "configures ollama_api_base and default_model from ENV" do
    previous_env = ENV.to_h.slice("OLLAMA_API_BASE", "OLLAMA_MODEL")
    previous_config = {
      ollama_api_base: RubyLLM.config.ollama_api_base,
      default_model: RubyLLM.config.default_model,
      context_budget: RubyLLM.config.context_budget
    }

    ENV["OLLAMA_API_BASE"] = "http://localhost:11434/v1"
    ENV["OLLAMA_MODEL"] = "Qwen3.6-35B-A3B-NVFP4"

    load Rails.root.join("config/initializers/ruby_llm.rb")

    assert_equal "http://localhost:11434/v1", RubyLLM.config.ollama_api_base
    assert_equal "Qwen3.6-35B-A3B-NVFP4", RubyLLM.config.default_model
    assert_equal({ per_result: 0.25, per_request: 0.7 }, RubyLLM.config.context_budget)
  ensure
    previous_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    RubyLLM.configure do |config|
      config.ollama_api_base = previous_config[:ollama_api_base]
      config.default_model = previous_config[:default_model]
      config.context_budget = previous_config[:context_budget]
    end
  end
end
