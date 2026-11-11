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

    broadcast_state(
      status_message: "Upserted #{upserted.size} #{'pantheon'.pluralize(upserted.size)} (#{Pantheon.count} total).",
      status_kind: :success,
      running: false
    )
  rescue StandardError => e
    Rails.logger.error("[PopulatePantheonsJob] #{e.class}: #{e.message}")
    broadcast_state(
      status_message: "Failed to populate pantheons: #{e.message}",
      status_kind: :error,
      running: false
    )
  end

  private

  def extract_pantheons(response)
    payload = response.parsed
    payload ||= parse_json_payload(response.content)

    case payload
    when Hash
      Array(payload["pantheons"])
    when Array
      payload
    else
      []
    end
  end

  def parse_json_payload(raw_content)
    text = raw_content.to_s.strip
    return nil if text.blank?

    # Strip reasoning blocks or markdown code fences that local models sometimes emit.
    cleaned = text
      .gsub(%r{<think>.*?</think>}m, "")
      .strip
      .sub(/\A```(?:json)?\s*/i, "")
      .sub(/\s*```\z/, "")
      .strip

    JSON.parse(cleaned)
  rescue JSON::ParserError
    extract_embedded_json(cleaned)
  end

  def extract_embedded_json(text)
    obj_start = text.index("{")
    obj_end = text.rindex("}")
    if obj_start && obj_end && obj_end > obj_start
      return JSON.parse(text[obj_start..obj_end])
    end

    arr_start = text.index("[")
    arr_end = text.rindex("]")
    if arr_start && arr_end && arr_end > arr_start
      return JSON.parse(text[arr_start..arr_end])
    end

    nil
  rescue JSON::ParserError
    nil
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
