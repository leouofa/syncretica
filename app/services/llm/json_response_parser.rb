# frozen_string_literal: true

module Llm
  # Parses JSON payloads from LLM responses, stripping reasoning blocks and
  # markdown code fences that local models sometimes emit.
  class JsonResponseParser
    def self.extract_list(response, key:)
      payload = parsed_payload(response)

      case payload
      when Hash
        Array(payload[key.to_s])
      when Array
        payload
      else
        []
      end
    end

    def self.extract_hash(response, key: nil)
      payload = parsed_payload(response)
      return {} unless payload.is_a?(Hash)

      if key.present?
        nested = payload[key.to_s]
        return nested if nested.is_a?(Hash)
      end

      payload
    end

    def self.parsed_payload(response)
      response.parsed || parse(response.content)
    end
    private_class_method :parsed_payload

    def self.parse(raw_content)
      text = raw_content.to_s.strip
      return nil if text.blank?

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

    def self.extract_embedded_json(text)
      candidates = [ [ "{", "}" ], [ "[", "]" ] ]
        .filter_map do |open_char, close_char|
          start_idx = text.index(open_char)
          end_idx = text.rindex(close_char)
          next unless start_idx && end_idx && end_idx > start_idx

          [ start_idx, end_idx ]
        end
        .sort_by(&:first)

      candidates.each do |start_idx, end_idx|
        return JSON.parse(text[start_idx..end_idx])
      rescue JSON::ParserError
        next
      end

      nil
    end
    private_class_method :extract_embedded_json
  end
end
