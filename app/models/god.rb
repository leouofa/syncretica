# frozen_string_literal: true

class God < ApplicationRecord
  belongs_to :pantheon

  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :description, with: ->(value) { value.to_s.strip }
  normalizes :themes, with: ->(value) { normalize_themes(value) }

  validates :name, presence: true, uniqueness: { scope: :pantheon_id, case_sensitive: false }
  validates :description, presence: true
  validate :themes_must_be_string_array

  scope :ordered, -> { order(:name) }

  # Returns [pantheon, Array<God>] pairs ordered by pantheon name then god name.
  def self.grouped_by_pantheon
    includes(:pantheon)
      .joins(:pantheon)
      .order("pantheons.name ASC, gods.name ASC")
      .group_by(&:pantheon)
      .to_a
  end

  # Upserts an enumerable of { name:, description:, themes: } entries scoped to
  # the given pantheon, matching case-insensitively on normalized name.
  def self.upsert_batch!(pantheon, entries)
    raise ArgumentError, "pantheon must be present" if pantheon.nil?

    transaction do
      Array(entries).filter_map do |entry|
        attrs = entry.respond_to?(:to_h) ? entry.to_h.symbolize_keys : {}
        name = attrs[:name].to_s.squish
        description = attrs[:description].to_s.strip
        next if name.blank? || description.blank?

        themes = normalize_themes(attrs[:themes])
        upsert_one!(pantheon: pantheon, name: name, description: description, themes: themes)
      end
    end
  end

  def self.normalize_themes(value)
    items =
      case value
      when Array
        value
      when String
        value.split(",")
      else
        []
      end

    items.filter_map { |item| item.to_s.squish.presence }.uniq(&:downcase)
  end

  def self.upsert_one!(pantheon:, name:, description:, themes:)
    scope = pantheon.gods
    record = scope.where("LOWER(name) = ?", name.downcase).first_or_initialize
    record.assign_attributes(name: name, description: description, themes: themes)
    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record = scope.where("LOWER(name) = ?", name.downcase).first!
    record.update!(name: name, description: description, themes: themes)
    record
  end
  private_class_method :upsert_one!

  private

  def themes_must_be_string_array
    unless themes.is_a?(Array) && themes.all? { |item| item.is_a?(String) && item.present? }
      errors.add(:themes, "must be a list of non-empty strings")
    end
  end
end
