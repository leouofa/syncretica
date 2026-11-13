# frozen_string_literal: true

class GenerateEmbeddingJob < ApplicationJob
  EMBEDDABLE_MODELS = {
    "God" => God,
    "Myth" => Myth
  }.freeze

  queue_as :default
  sidekiq_options retry: 0

  def self.stream_name_for(record)
    "#{record.model_name.singular}_#{record.id}"
  end

  def self.target_id_for(record)
    "#{record.model_name.singular}_#{record.id}_embedding_panel"
  end

  def perform(record_type, record_id)
    model_class = EMBEDDABLE_MODELS[record_type.to_s]
    raise ArgumentError, "Unsupported embeddable type: #{record_type}" unless model_class

    record = model_class.find(record_id)

    track_progress(message: "Generating embedding with #{Llm::EmbeddingGenerator.configured_model}...")

    broadcast_panel(
      record,
      running: true,
      status_message: "Generating embedding with #{Llm::EmbeddingGenerator.configured_model}...",
      status_kind: :info
    )

    record.generate_embedding!

    track_completed(
      message: "Embedding generated (#{record.embedding_model}).",
      result: { record_type: record_type, record_id: record.id, model: record.embedding_model, embedded_at: record.embedded_at }
    )

    broadcast_panel(
      record,
      running: false,
      status_message: "Embedding generated (#{record.embedding_model}).",
      status_kind: :success
    )
  rescue StandardError => e
    Rails.logger.error("[GenerateEmbeddingJob] #{record_type}##{record_id} #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to generate embedding: #{e.message}")
    broadcast_panel(
      record,
      running: false,
      status_message: "Failed to generate embedding: #{e.message}",
      status_kind: :error
    ) if record
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def broadcast_panel(record, running:, status_message:, status_kind:)
    Turbo::StreamsChannel.broadcast_replace_to(
      self.class.stream_name_for(record),
      target: self.class.target_id_for(record),
      partial: "shared/embedding_panel",
      locals: {
        record: record,
        action_path: Rails.application.routes.url_helpers.polymorphic_path([ :generate_embedding, record ]),
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )
  end
end
