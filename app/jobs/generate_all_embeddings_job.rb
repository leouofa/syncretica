# frozen_string_literal: true

class GenerateAllEmbeddingsJob < ApplicationJob
  STREAM_NAME = "settings_embeddings"
  EMBEDDABLE_MODELS = {
    "God" => { klass: God, includes: :pantheon },
    "Myth" => { klass: Myth, includes: { god: :pantheon } }
  }.freeze

  queue_as :default
  sidekiq_options retry: 0

  def self.target_id_for(model_type)
    "settings_#{model_type.to_s.downcase}_embeddings"
  end

  def self.stats_for(model_class)
    {
      total: model_class.count,
      embedded: model_class.where.not(embedding: nil).count
    }
  end

  def perform(model_type, only_missing: true)
    config = EMBEDDABLE_MODELS[model_type.to_s]
    raise ArgumentError, "Unsupported embeddable type: #{model_type}" unless config

    model_class = config[:klass]
    scope = only_missing ? model_class.where(embedding: nil) : model_class.all
    records = scope.includes(config[:includes]).order(:id).to_a

    if records.empty?
      message = model_class.none? ? "No #{model_type.downcase.pluralize} found." : "All #{model_type.downcase.pluralize} already have embeddings."
      track_completed(message: message, result: { succeeded: 0, failed: 0, total_targeted: 0 })
      broadcast_section(model_type, model_class, running: false, status_message: message, status_kind: :info)
      return { succeeded: 0, failed: 0, total_targeted: 0 }
    end

    succeeded, failed = embed_records(model_type, model_class, records, only_missing:)
    summary = build_summary(model_type, succeeded:, failed:, total_targeted: records.size)

    if failed == records.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(message: summary[:message], result: { succeeded: succeeded, failed: failed, total_targeted: records.size })
    end

    broadcast_section(
      model_type,
      model_class,
      running: false,
      status_message: summary[:message],
      status_kind: summary[:kind]
    )

    { succeeded: succeeded, failed: failed, total_targeted: records.size }
  rescue StandardError => e
    Rails.logger.error("[GenerateAllEmbeddingsJob] #{model_type} #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to generate #{model_type.downcase} embeddings: #{e.message}")
    if config
      broadcast_section(
        model_type,
        config[:klass],
        running: false,
        status_message: "Failed to generate #{model_type.downcase} embeddings: #{e.message}",
        status_kind: :error
      )
    end
  end

  private

  def embed_records(model_type, model_class, records, only_missing:)
    succeeded = 0
    failed = 0
    label = model_type.downcase

    records.each_with_index do |record, index|
      msg = "Generating #{label} embeddings (#{index + 1}/#{records.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: records.size, model_type: model_type })
      broadcast_section(
        model_type,
        model_class,
        running: true,
        running_mode: only_missing ? :missing : :all,
        status_message: msg,
        status_kind: :info
      )

      begin
        record.generate_embedding!
        succeeded += 1
      rescue StandardError => e
        Rails.logger.error("[GenerateAllEmbeddingsJob] #{model_type}##{record.id} #{e.class}: #{e.message}")
        failed += 1
      end
    end

    [ succeeded, failed ]
  end

  def build_summary(model_type, succeeded:, failed:, total_targeted:)
    plural_label = model_type.downcase.pluralize(succeeded)
    if failed.zero?
      {
        kind: :success,
        message: "Generated embeddings for #{succeeded} #{plural_label}."
      }
    elsif succeeded.zero?
      {
        kind: :error,
        message: "Failed to generate embeddings for all #{total_targeted} #{model_type.downcase.pluralize(total_targeted)}."
      }
    else
      {
        kind: :error,
        message: "Generated #{succeeded} #{plural_label}; #{failed} failed."
      }
    end
  end

  def broadcast_section(model_type, model_class, running:, status_message:, status_kind:, running_mode: nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: self.class.target_id_for(model_type),
      partial: "settings/embedding_section",
      locals: {
        model_type: model_type,
        stats: self.class.stats_for(model_class),
        running: running,
        running_mode: running_mode,
        status_message: status_message,
        status_kind: status_kind
      }
    )
  end
end
