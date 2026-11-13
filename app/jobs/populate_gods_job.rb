# frozen_string_literal: true

class PopulateGodsJob < ApplicationJob
  STREAM_NAME = "gods"

  queue_as :default
  sidekiq_options retry: 0

  def perform(pantheon_id: nil)
    Llm::ModelRegistry.ensure_configured_model!

    pantheons = if pantheon_id.present?
                  Pantheon.where(id: pantheon_id).to_a
    else
                  Pantheon.ordered.to_a
    end

    if pantheons.empty?
      msg = pantheon_id.present? ? "Pantheon with ID #{pantheon_id} not found." : "No pantheons found. Populate pantheons first before discovering gods."
      track_failed(error: msg, message: msg)
      broadcast_state(
        status_message: msg,
        status_kind: :error,
        running: false
      )
      return { total_upserted: 0, failed_pantheons: [] }
    end

    total_upserted, failed_pantheons = populate_across_pantheons(pantheons)
    summary = build_summary(total_upserted: total_upserted, total_pantheons: pantheons.size, failed_pantheons: failed_pantheons)

    if failed_pantheons.size == pantheons.size
      track_failed(error: summary[:message], message: summary[:message])
    else
      track_completed(
        message: summary[:message],
        result: { total_upserted: total_upserted, total_gods: God.count, failed_pantheons: failed_pantheons }
      )
    end

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )

    { total_upserted: total_upserted, failed_pantheons: failed_pantheons }
  rescue StandardError => e
    Rails.logger.error("[PopulateGodsJob] #{e.class}: #{e.message}")
    track_failed(error: e, message: "Failed to populate gods: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate gods: #{e.message}",
      status_kind: :error,
      running: false
    )
  end

  def populate_pantheon!(pantheon)
    existing_names = pantheon.gods.ordered.pluck(:name)
    chat = GodDiscoveryAgent.create!(
      pantheon_name: pantheon.name,
      pantheon_description: pantheon.description,
      existing_names: existing_names
    )
    response = chat.ask(discovery_prompt_for(pantheon))

    entries = Llm::JsonResponseParser.extract_list(response, key: "gods")
    upserted = God.upsert_batch!(pantheon, entries)
    raise "LLM response did not contain any valid gods for #{pantheon.name}." if upserted.empty?

    upserted.size
  end

  private

  def populate_across_pantheons(pantheons)
    total_upserted = 0
    failed_pantheons = []

    pantheons.each_with_index do |pantheon, index|
      msg = "Discovering gods for #{pantheon.name} (#{index + 1}/#{pantheons.size})..."
      track_progress(message: msg, progress: { current: index + 1, total: pantheons.size, pantheon: pantheon.name })
      broadcast_state(
        status_message: msg,
        status_kind: :info,
        running: true
      )

      total_upserted += populate_pantheon!(pantheon)
    rescue StandardError => e
      Rails.logger.error("[PopulateGodsJob] Pantheon=#{pantheon.name} #{e.class}: #{e.message}")
      failed_pantheons << pantheon.name
    end

    [ total_upserted, failed_pantheons ]
  end

  def discovery_prompt_for(pantheon)
    "Find all major and notable deities belonging to the #{pantheon.name} pantheon and return their names, descriptions, and themes as JSON."
  end

  def build_summary(total_upserted:, total_pantheons:, failed_pantheons:)
    total_gods = God.count
    if failed_pantheons.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'god'.pluralize(total_upserted)} across #{total_pantheons} #{'pantheon'.pluralize(total_pantheons)} (#{total_gods} total)."
      }
    elsif failed_pantheons.size == total_pantheons
      {
        kind: :error,
        message: "Failed to populate gods for all pantheons: #{failed_pantheons.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'god'.pluralize(total_upserted)} (#{total_gods} total). Failed pantheons: #{failed_pantheons.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    pantheon_groups = God.grouped_by_pantheon
    total_gods_count = God.count
    pantheons_count = Pantheon.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "gods_populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "gods_populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_gods_path,
        idle_label: "Populate Gods",
        running_label: "Discovering Gods...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "gods_list",
      partial: "pages/gods_list",
      locals: {
        pantheon_groups: pantheon_groups,
        total_gods_count: total_gods_count,
        pantheons_count: pantheons_count
      }
    )
  end
end
