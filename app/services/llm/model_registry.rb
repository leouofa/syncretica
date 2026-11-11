# frozen_string_literal: true

module Llm
  # Registers local/custom models (such as the configured Ollama-compatible
  # model from ENV) in RubyLLM's ActiveRecord model store so persisted Chat
  # records resolve them without requiring assume_model_exists at every call site.
  class ModelRegistry
    DEFAULT_CONTEXT_WINDOW = 262_144
    DEFAULT_CAPABILITIES = %w[function_calling streaming structured_output].freeze
    DEFAULT_MODALITIES = { "input" => %w[text], "output" => %w[text] }.freeze

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
