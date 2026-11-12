# frozen_string_literal: true

class ClusterReportSummary < ApplicationRecord
  belongs_to :cluster_report
  belongs_to :cluster_group
  belongs_to :chat, optional: true

  validates :content, presence: true
  validates :cluster_group_id, uniqueness: { scope: :cluster_report_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  scope :ordered, -> { order(:position, :id) }
end
