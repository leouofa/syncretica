# frozen_string_literal: true

class ClusterSubReport < ApplicationRecord
  belongs_to :cluster_report
  belongs_to :chat, optional: true

  validates :content, presence: true
  validates :batch_index, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :batch_index, uniqueness: { scope: :cluster_report_id }

  scope :ordered, -> { order(:batch_index, :id) }
end
