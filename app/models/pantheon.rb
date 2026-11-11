# frozen_string_literal: true

class Pantheon < ApplicationRecord
  normalizes :name, with: ->(value) { value.to_s.squish }
  normalizes :description, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :description, presence: true

  scope :ordered, -> { order(:name) }

  # Upserts an enumerable of { name:, description: } entries, matching
  # case-insensitively on normalized name and overwriting description.
  def self.upsert_batch!(entries)
    transaction do
      Array(entries).filter_map do |entry|
        attrs = entry.respond_to?(:to_h) ? entry.to_h.symbolize_keys : {}
        name = attrs[:name].to_s.squish
        description = attrs[:description].to_s.strip
        next if name.blank? || description.blank?

        upsert_one!(name: name, description: description)
      end
    end
  end

  def self.upsert_one!(name:, description:)
    record = where("LOWER(name) = ?", name.downcase).first_or_initialize
    record.assign_attributes(name: name, description: description)
    record.save!
    record
  rescue ActiveRecord::RecordNotUnique
    record = where("LOWER(name) = ?", name.downcase).first!
    record.update!(name: name, description: description)
    record
  end
  private_class_method :upsert_one!
end
