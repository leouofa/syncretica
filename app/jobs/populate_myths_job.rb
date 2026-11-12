# frozen_string_literal: true

class PopulateMythsJob < ApplicationJob
  STREAM_NAME = "myths"

  queue_as :default
  sidekiq_options retry: 0

  def perform
    Llm::ModelRegistry.ensure_configured_model!

    gods = God.includes(:pantheon).joins(:pantheon).order("pantheons.name ASC, gods.name ASC").to_a
    if gods.empty?
      broadcast_state(
        status_message: "No gods found. Populate gods first before discovering myths.",
        status_kind: :error,
        running: false
      )
      return
    end

    total_upserted, failed_gods = populate_across_gods(gods)
    summary = build_summary(total_upserted: total_upserted, total_gods: gods.size, failed_gods: failed_gods)

    broadcast_state(
      status_message: summary[:message],
      status_kind: summary[:kind],
      running: false
    )
  rescue StandardError => e
    Rails.logger.error("[PopulateMythsJob] #{e.class}: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate myths: #{e.message}",
      status_kind: :error,
      running: false
    )
  end

  private

  def populate_across_gods(gods)
    total_upserted = 0
    failed_gods = []

    gods.each_with_index do |god, index|
      broadcast_state(
        status_message: "Discovering myths for #{god.name} (#{index + 1}/#{gods.size})...",
        status_kind: :info,
        running: true
      )

      populate_god!(god)
      total_upserted += 1
    rescue StandardError => e
      Rails.logger.error("[PopulateMythsJob] God=#{god.name} #{e.class}: #{e.message}")
      failed_gods << god.name
    end

    [ total_upserted, failed_gods ]
  end

  def populate_god!(god)
    chat = MythDiscoveryAgent.create!(
      god_name: god.name,
      god_description: god.description,
      god_themes: god.themes,
      pantheon_name: god.pantheon.name
    )
    response = chat.ask(discovery_prompt_for(god))

    themes_hash = Llm::JsonResponseParser.extract_hash(response, key: "themes")
    normalized = Myth.normalize_themes(themes_hash)
    raise "LLM response did not contain any valid mythical themes for #{god.name}." if normalized.empty?

    Myth.upsert_for_god!(god, normalized)
  end

  def discovery_prompt_for(god)
    "Identify the core mythical themes for #{god.name} (#{god.pantheon.name} pantheon) and return them as a JSON object mapping each theme title to its description."
  end

  def build_summary(total_upserted:, total_gods:, failed_gods:)
    total_myths = Myth.count
    if failed_gods.empty?
      {
        kind: :success,
        message: "Upserted #{total_upserted} #{'myth'.pluralize(total_upserted)} across #{total_gods} #{'god'.pluralize(total_gods)} (#{total_myths} total)."
      }
    elsif failed_gods.size == total_gods
      {
        kind: :error,
        message: "Failed to populate myths for all gods: #{failed_gods.join(', ')}."
      }
    else
      {
        kind: :error,
        message: "Upserted #{total_upserted} #{'myth'.pluralize(total_upserted)} (#{total_myths} total). Failed gods: #{failed_gods.join(', ')}."
      }
    end
  end

  def broadcast_state(status_message:, status_kind:, running:)
    pantheon_groups = Myth.grouped_by_pantheon
    total_myths_count = Myth.count
    gods_count = God.count

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "myths_populate_controls",
      partial: "pages/populate_controls",
      locals: {
        target_id: "myths_populate_controls",
        action_path: Rails.application.routes.url_helpers.populate_myths_path,
        idle_label: "Populate Myths",
        running_label: "Discovering Myths...",
        running: running,
        status_message: status_message,
        status_kind: status_kind
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      STREAM_NAME,
      target: "myths_list",
      partial: "pages/myths_list",
      locals: {
        pantheon_groups: pantheon_groups,
        total_myths_count: total_myths_count,
        gods_count: gods_count
      }
    )
  end
end
