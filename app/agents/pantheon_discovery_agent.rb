# frozen_string_literal: true

class PantheonDiscoveryAgent < ApplicationAgent
  inputs :existing_names

  instructions do
    existing = Array(existing_names).compact_blank
    existing_clause =
      if existing.any?
        "Existing pantheon names already in our database: #{existing.join(', ')}. " \
          "Reuse these exact names when referring to the same pantheons so records update cleanly without near-duplicates, " \
          "and include any missing pantheons as well."
      else
        "Use clear, concise canonical names (e.g., 'Greek', 'Norse', 'Egyptian', 'Hindu', 'Yoruba')."
      end

    <<~INSTRUCTIONS.squish
      You are a comparative mythology scholar.
      Identify all major historical, classical, and indigenous pantheons of gods across world mythologies.
      For each pantheon, provide its canonical name and a concise, informative description covering its cultural or geographic origin, key themes, and notable deities.
      #{existing_clause}
      Respond ONLY with valid JSON matching this exact structure (no markdown fences or commentary):
      {"pantheons":[{"name":"Greek","description":"..."}]}
    INSTRUCTIONS
  end
end
