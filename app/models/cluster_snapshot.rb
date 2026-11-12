# frozen_string_literal: true

class ClusterSnapshot < ApplicationRecord
  has_many :cluster_groups, dependent: :destroy
  has_many :cluster_memberships, through: :cluster_groups

  validates :target_type, presence: true, inclusion: { in: %w[God Myth] }
  validates :level, presence: true, inclusion: { in: 1..15 }
  validates :distance_threshold, presence: true, numericality: { greater_than: 0 }
  validates :title, presence: true

  scope :ordered, -> { order(created_at: :desc) }
  scope :for_target, ->(type) { where(target_type: type) }

  def target_class
    target_type.constantize
  end
end
