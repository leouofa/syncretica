# frozen_string_literal: true

module Llm
  # Registers local/custom models (such as the configured Ollama-compatible
  # model from ENV) in RubyLLM's ActiveRecord model store so persisted Chat
  # records resolve them without requiring assume_model_exists at every call site.
  class ModelRegistry
    DEFAULT_CONTEXT_WINDOW = 262_144
    DEFAULT_CAPABILITIES = %w[function_calling streaming structured_output].freeze
    DEFAULT_MODALITIES = { "input" => %w[text], "output" => %w[text] }.freeze

    CONTEXT_WINDOW_PRESETS = [
      { label: "32K",  tokens: 32_768 },
      { label: "64K",  tokens: 65_536 },
      { label: "128K", tokens: 131_072 },
      { label: "256K", tokens: 262_144 },
      { label: "512K", tokens: 524_288 },
      { label: "1M",   tokens: 1_048_576 }
    ].freeze

    def self.current_context_window(model_id: ENV["OLLAMA_MODEL"], provider: "ollama")
      model_name = model_id.presence || ENV["OLLAMA_MODEL"]
      return DEFAULT_CONTEXT_WINDOW if model_name.blank?

      record = RubyLLM::ActiveRecord::Model.find_by(provider: provider.to_s, model_id: model_name.to_s)
      record&.context_window || ENV.fetch("OLLAMA_CONTEXT_WINDOW", DEFAULT_CONTEXT_WINDOW).to_i
    rescue StandardError
      DEFAULT_CONTEXT_WINDOW
    end

    def self.update_context_window!(tokens, model_id: ENV["OLLAMA_MODEL"], provider: "ollama")
      token_count = tokens.to_i
      raise ArgumentError, "Context window must be at least 4,096 tokens" if token_count < 4_096

      model_name = model_id.presence || ENV["OLLAMA_MODEL"]
      raise ArgumentError, "No model configured to update" if model_name.blank?

      record = ensure_configured_model!(
        model_id: model_name,
        provider: provider,
        context_window: token_count
      )
      record.update!(context_window: token_count)
      RubyLLM.models.load_from_store if RubyLLM.config.model_registry_store
      record.context_window
    end

    def self.digest_char_budget(fraction: 0.55, chars_per_token: 4)
      window = current_context_window
      (window * chars_per_token * fraction).to_i.clamp(30_000, 3_000_000)
    end

    def self.ensure_configured_model!(
      model_id: ENV["OLLAMA_MODEL"],
      provider: "ollama",
      context_window: DEFAULT_CONTEXT_WINDOW
    )
      return nil if model_id.blank?

      # Ensure acts_as_chat has registered RubyLLM::ActiveRecord::Model as the store.
      Chat

      seed_bundled_models_if_empty!

      record = RubyLLM::ActiveRecord::Model.find_or_initialize_by(
        provider: provider.to_s,
        model_id: model_id.to_s
      )
      record.assign_attributes(
        name: model_id.to_s,
        family: model_id.to_s.split(/[-:]/).first.downcase,
        context_window: record.context_window || context_window,
        capabilities: record.capabilities.presence || DEFAULT_CAPABILITIES,
        modalities: record.modalities.presence || DEFAULT_MODALITIES,
        unlisted_at: nil
      )
      record.save!

      RubyLLM.models.load_from_store if RubyLLM.config.model_registry_store
      record
    end

    def self.seed_bundled_models_if_empty!
      return unless RubyLLM::ActiveRecord::Model.none?

      RubyLLM::ActiveRecord::Model.save_to_database(RubyLLM.models)
    end
    private_class_method :seed_bundled_models_if_empty!
  end
end
