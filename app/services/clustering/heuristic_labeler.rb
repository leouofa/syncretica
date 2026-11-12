# frozen_string_literal: true

module Clustering
  class HeuristicLabeler
    STOP_WORDS = %w[the and of in a to with for on is at by as an from or into].to_set.freeze

    def self.label(records)
      new(records).label
    end

    def initialize(records)
      @records = Array(records)
    end

    def label
      return { title: "Empty Cluster", shared_themes: [] } if @records.empty?

      top_themes = extract_top_themes
      prominent_names = extract_prominent_names

      title = build_title(top_themes, prominent_names)
      { title: title, shared_themes: top_themes }
    end

    private

    def extract_top_themes
      theme_counts = Hash.new(0)

      @records.each do |record|
        themes_for(record).each do |theme|
          normalized = theme.to_s.squish.downcase
          next if normalized.blank? || STOP_WORDS.include?(normalized)

          theme_counts[normalized] += 1
        end
      end

      # Sort by frequency descending, then length
      theme_counts.sort_by { |theme, count| [ -count, -theme.length ] }
                  .take(4)
                  .map { |theme, _| theme.titleize }
    end

    def themes_for(record)
      case record
      when God
        record.themes || []
      when Myth
        record.themes.is_a?(Hash) ? record.themes.keys : []
      else
        []
      end
    end

    def extract_prominent_names
      @records.take(3).map do |record|
        case record
        when God then record.name
        when Myth then record.god&.name || "Myth ##{record.id}"
        else record.to_s
        end
      end
    end

    def build_title(themes, names)
      theme_phrase = themes.take(2).join(" & ")

      if theme_phrase.present?
        "#{theme_phrase} Domain"
      elsif names.any?
        "#{names.first} & Counterparts"
      else
        "Archetype Cluster"
      end
    end
  end
end
