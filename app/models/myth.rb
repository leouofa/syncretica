# frozen_string_literal: true

class Myth < ApplicationRecord
  belongs_to :god

  normalizes :themes, with: ->(value) { normalize_themes(value) }

  validates :god_id, uniqueness: true
  validate :themes_must_be_string_hash

  # Returns [pantheon, Array<Myth>] pairs ordered by pantheon name then god name.
  def self.grouped_by_pantheon
    includes(god: :pantheon)
      .joins(god: :pantheon)
      .order("pantheons.name ASC, gods.name ASC")
      .group_by { |myth| myth.god.pantheon }
      .to_a
  end

  # Upserts the single Myth record for the given god with a { title => description } hash.
  def self.upsert_for_god!(god, themes)
    raise ArgumentError, "god must be present" if god.nil?

    normalized = normalize_themes(themes)
    raise ArgumentError, "themes must not be empty" if normalized.empty?

    transaction do
      record = find_or_initialize_by(god: god)
      record.themes = normalized
      record.save!
      record
    end
  rescue ActiveRecord::RecordNotUnique
    record = find_by!(god: god)
    record.update!(themes: normalized)
    record
  end

  def self.normalize_themes(value)
    return {} unless value.is_a?(Hash)

    value.each_with_object({}) do |(key, description), normalized|
      clean_key = key.to_s.squish
      clean_description = description.to_s.strip
      next if clean_key.blank? || clean_description.blank?

      normalized[clean_key] = clean_description
    end
  end

  private

  def themes_must_be_string_hash
    valid = themes.is_a?(Hash) &&
            themes.any? &&
            themes.all? { |k, v| k.is_a?(String) && k.present? && v.is_a?(String) && v.present? }

    errors.add(:themes, "must be a non-empty JSON object of theme titles and descriptions") unless valid
  end
end
