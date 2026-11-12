# frozen_string_literal: true

class SettingsController < ApplicationController
  def show
    @god_stats = GenerateAllEmbeddingsJob.stats_for(God)
    @myth_stats = GenerateAllEmbeddingsJob.stats_for(Myth)
    @embedding_config = {
      model: Llm::EmbeddingGenerator.configured_model,
      api_base: Llm::EmbeddingGenerator.configured_api_base,
      dimensions: Llm::EmbeddingGenerator::DIMENSIONS
    }
    @llm_config = {
      model: ENV["OLLAMA_MODEL"],
      api_base: ENV["OLLAMA_API_BASE"],
      context_window: Llm::ModelRegistry.current_context_window,
      digest_char_budget: Llm::ModelRegistry.digest_char_budget,
      presets: Llm::ModelRegistry::CONTEXT_WINDOW_PRESETS
    }
  end

  def update_context_window
    tokens = params[:context_window].to_i
    Llm::ModelRegistry.update_context_window!(tokens)
    redirect_to settings_path, notice: "LLM Context Window updated to #{tokens.to_fs(:delimited)} tokens."
  rescue StandardError => e
    redirect_to settings_path, alert: "Failed to update context window: #{e.message}"
  end

  def generate_embeddings
    model_type = params[:model_type].to_s
    config = GenerateAllEmbeddingsJob::EMBEDDABLE_MODELS[model_type]
    return head :unprocessable_entity unless config

    only_missing = ActiveModel::Type::Boolean.new.cast(params.fetch(:only_missing, true))
    GenerateAllEmbeddingsJob.perform_later(model_type, only_missing: only_missing)

    action_label = only_missing ? "missing #{model_type.downcase}" : "all #{model_type.downcase}"
    message = "Queued embedding generation for #{action_label.pluralize}..."

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          GenerateAllEmbeddingsJob.target_id_for(model_type),
          partial: "settings/embedding_section",
          locals: {
            model_type: model_type,
            stats: GenerateAllEmbeddingsJob.stats_for(config[:klass]),
            running: true,
            running_mode: only_missing ? :missing : :all,
            status_message: message,
            status_kind: :info
          }
        )
      end
      format.html { redirect_to settings_path, notice: message }
    end
  end
end
