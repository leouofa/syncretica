# frozen_string_literal: true

module Api
  module V1
    class SettingsController < BaseController
      def show
        render_success(Serializer.settings_payload)
      end

      def update_context_window
        tokens = params.require(:context_window).to_i
        updated = Llm::ModelRegistry.update_context_window!(tokens)
        render_success({ context_window: updated, message: "LLM Context Window updated to #{updated} tokens." })
      end

      def generate_embeddings
        model_type = params.require(:model_type).to_s.classify
        config = GenerateAllEmbeddingsJob::EMBEDDABLE_MODELS[model_type]
        return render_error(code: "invalid_model_type", message: "model_type must be either 'God' or 'Myth'") unless config

        only_missing = boolean_param(:only_missing, default: true)
        job = GenerateAllEmbeddingsJob.perform_later(model_type, only_missing: only_missing)

        render_success(
          { job_id: job.job_id, model_type: model_type, only_missing: only_missing, status: "queued" },
          status: :accepted
        )
      end
    end
  end
end
