# frozen_string_literal: true

module Llm
  # Generates fixed-dimension vector embeddings using a dedicated Ollama-compatible
  # RubyLLM context so embedding calls stay isolated from the chat endpoint.
  class EmbeddingGenerator
    DEFAULT_API_BASE = "http://localhost:11434/v1"
    DEFAULT_MODEL = "qwen3-embedding:0.6b"
    DIMENSIONS = 1024

    def self.call(text, model: configured_model, api_base: configured_api_base, api_key: configured_api_key)
      raise ArgumentError, "text must not be blank" if text.blank?
      raise ArgumentError, "embedding model must not be blank" if model.blank?

      response = build_context(api_base: api_base, api_key: api_key).embed(
        text.to_s,
        model: model,
        provider: :ollama,
        assume_model_exists: true
      )

      vector = response.vector
      unless vector.is_a?(Array) && vector.size == DIMENSIONS && vector.all?(Numeric)
        actual_size = vector.is_a?(Array) ? vector.size : vector.class
        raise "Expected #{DIMENSIONS}-dimensional numeric vector from #{model}, got #{actual_size}"
      end

      {
        vector: vector.map(&:to_f),
        model: response.model.presence || model
      }
    end

    def self.configured_model
      ENV["EMBEDDING_MODEL"].presence || DEFAULT_MODEL
    end

    def self.configured_api_base
      ENV["EMBEDDING_API_BASE"].presence || DEFAULT_API_BASE
    end

    def self.configured_api_key
      ENV["EMBEDDING_API_KEY"].presence
    end

    def self.build_context(api_base:, api_key:)
      RubyLLM.context do |config|
        config.ollama_api_base = api_base
        config.ollama_api_key = api_key if api_key.present?
      end
    end
    private_class_method :build_context
  end
end
