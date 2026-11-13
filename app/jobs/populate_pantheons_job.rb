# frozen_string_literal: true

class PopulatePantheonsJob < ApplicationJob
  STREAM_NAME = "pantheons"
  DISCOVERY_PROMPT = "Find all major mythological and historical pantheons of gods from around the world and return their names and descriptions as JSON."

  queue_as :default
  sidekiq_options retry: 0

  def perform
    Llm::ModelRegistry.ensure_configured_model!

    existing_names = Pantheon.ordered.pluck(:name)
    chat = PantheonDiscoveryAgent.create!(existing_names: existing_names)
    response = chat.ask(DISCOVERY_PROMPT)

    entries = extract_pantheons(response)
    upserted = Pantheon.upsert_batch!(entries)
    raise "LLM response did not contain any valid pantheons." if upserted.empty?

    message = "Upserted #{upserted.size} #{'pantheon'.pluralize(upserted.size)} (#{Pantheon.count} total)."
    track_completed(message: message, result: { upserted_count: upserted.size, total_count: Pantheon.count })

    broadcast_state(
      status_message: message,
      status_kind: :success,
      running: false
    )
    { upserted_count: upserted.size, total_count: Pantheon.count }
  rescue StandardError => e
    Rails.logger.error("[PopulatePantheonsJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate pantheons: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate pantheons: #{e.message}",
      status_kind: :error,
      running: false
    )
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  private

  def called_via_perform_later?
    job_id.present?
  end

  def extract_pantheons(response)
    Llm::JsonResponseParser.extract_list(response, key: "pantheons")
  end

  def broadcast_state(status_message:, status_kind:, running:)
    pantheons = Pantheon.ordered.to_a

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "populate_controls",
      partial: "pages/populate_controls",
      locals: { running: running, status_message: status_message, status_kind: status_kind }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "pantheons_list",
      partial: "pages/pantheons_list",
      locals: { pantheons: pantheons }
    )
  end
end
