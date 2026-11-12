# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Llm::EmbeddingGeneratorTest < ActiveSupport::TestCase
  test "call configures an isolated RubyLLM context and returns normalized float vector and model" do
    sample_vector = Array.new(1024) { |i| i * 0.001 }
    captured_config = nil
    captured_embed_args = nil

    fake_context = Object.new
    fake_context.define_singleton_method(:embed) do |text, **kwargs|
      captured_embed_args = { text: text, kwargs: kwargs }
      OpenStruct.new(vector: sample_vector, model: "qwen3-embedding:0.6b")
    end

    with_stubbed_context(->(&block) {
      captured_config = Struct.new(:ollama_api_base, :ollama_api_key).new
      block.call(captured_config)
      fake_context
    }) do
      result = Llm::EmbeddingGenerator.call(
        "God: Zeus (Greek)",
        model: "qwen3-embedding:0.6b",
        api_base: "http://localhost:11434/v1",
        api_key: "secret"
      )

      assert_equal "http://localhost:11434/v1", captured_config.ollama_api_base
      assert_equal "secret", captured_config.ollama_api_key
      assert_equal "God: Zeus (Greek)", captured_embed_args[:text]
      assert_equal(
        { model: "qwen3-embedding:0.6b", provider: :ollama, assume_model_exists: true },
        captured_embed_args[:kwargs]
      )
      assert_equal 1024, result[:vector].size
      assert_equal "qwen3-embedding:0.6b", result[:model]
    end
  end

  test "call raises when vector dimensions do not match 1024" do
    fake_context = Object.new
    fake_context.define_singleton_method(:embed) do |_text, **_kwargs|
      OpenStruct.new(vector: [ 0.1, 0.2, 0.3 ], model: "qwen3-embedding:0.6b")
    end

    with_stubbed_context(->(&_block) { fake_context }) do
      error = assert_raises(RuntimeError) do
        Llm::EmbeddingGenerator.call("Hello")
      end
      assert_match "Expected 1024-dimensional numeric vector", error.message
    end
  end

  test "call raises ArgumentError on blank text" do
    assert_raises(ArgumentError) do
      Llm::EmbeddingGenerator.call("   ")
    end
  end

  private

  def with_stubbed_context(replacement)
    singleton = RubyLLM.singleton_class
    original = RubyLLM.method(:context)
    singleton.define_method(:context, &replacement)
    yield
  ensure
    singleton.define_method(:context, original)
  end
end
