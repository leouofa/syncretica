# frozen_string_literal: true

class GodDiscoveryAgent < ApplicationAgent
  inputs :pantheon_name, :pantheon_description, :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing god names already in our database for this pantheon: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same deities so records update cleanly without near-duplicates, " \
          "and include any missing notable deities from this pantheon as well."
      else
        "Use clear, concise canonical names (e.g., 'Zeus', 'Athena', 'Apollo')."
      end

    context_clause = pantheon_description.present? ? "Pantheon context: #{pantheon_description}" : ""

    <<~INSTRUCTIONS.squish
      You are a comparative mythology scholar.
      Identify all major and notable deities belonging to the #{pantheon_name} pantheon.
      #{context_clause}
      For each deity, provide:
      1. Its canonical name.
      2. A concise, informative description covering its mythological role, domain, and notable myths or attributes.
      3. A JSON array of 2 to 6 concise thematic domains or motifs as lowercase strings (e.g., ["sky", "thunder", "kingship"]).
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"gods":[{"name":"Zeus","description":"...","themes":["sky","thunder","kingship"]}]}
    INSTRUCTIONS
  end
end
