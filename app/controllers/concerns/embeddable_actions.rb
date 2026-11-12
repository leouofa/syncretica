# frozen_string_literal: true

module EmbeddableActions
  extend ActiveSupport::Concern

  private

  def enqueue_embedding_generation(record)
    GenerateEmbeddingJob.perform_later(record.class.name, record.id)
    message = "Queued embedding generation with #{Llm::EmbeddingGenerator.configured_model}..."

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          GenerateEmbeddingJob.target_id_for(record),
          partial: "shared/embedding_panel",
          locals: {
            record: record,
            action_path: polymorphic_path([ :generate_embedding, record ]),
            running: true,
            status_message: message,
            status_kind: :info
          }
        )
      end
      format.html { redirect_to polymorphic_path(record), notice: message }
    end
  end
end
