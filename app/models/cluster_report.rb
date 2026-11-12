# frozen_string_literal: true

class ClusterReport < ApplicationRecord
  STATUS_PENDING   = "pending"
  STATUS_RUNNING   = "running"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED    = "failed"

  STATUSES = [ STATUS_PENDING, STATUS_RUNNING, STATUS_COMPLETED, STATUS_FAILED ].freeze

  DEFAULT_PROMPT = "Find interesting patterns across myths or gods, highlighting cross-pantheon archetypes, structural motifs, and surprising connections."

  PRESET_PROMPTS = [
    "Find interesting patterns across myths or gods",
    "Identify cross-pantheon archetypes and functional equivalents",
    "Spot unexpected connections, overlaps, and thematic outliers",
    "Analyze the balance of creation, order, trickery, and destruction motifs"
  ].freeze

  belongs_to :cluster_snapshot
  belongs_to :chat, optional: true

  validates :title, presence: true
  validates :prompt, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :ordered, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: STATUS_COMPLETED) }
  scope :in_progress, -> { where(status: [ STATUS_PENDING, STATUS_RUNNING ]) }

  before_validation :assign_default_title

  def pending?
    status == STATUS_PENDING
  end

  def running?
    status == STATUS_RUNNING
  end

  def in_progress?
    pending? || running?
  end

  def completed?
    status == STATUS_COMPLETED
  end

  def failed?
    status == STATUS_FAILED
  end

  def mark_running!
    update!(status: STATUS_RUNNING)
  end

  def mark_completed!(markdown_content:, refined_title: nil)
    attrs = {
      status: STATUS_COMPLETED,
      content: markdown_content,
      error_message: nil,
      completed_at: Time.current
    }
    attrs[:title] = refined_title if refined_title.present?
    update!(attrs)
  end

  def mark_failed!(message)
    update!(
      status: STATUS_FAILED,
      error_message: message.to_s.truncate(1000)
    )
  end

  private

  def assign_default_title
    clean_prompt = prompt.to_s.squish
    if clean_prompt.present?
      self.title = clean_prompt.truncate(72) if title.blank? || title.start_with?("Report:")
    elsif title.blank?
      self.title = cluster_snapshot.present? ? "Report: #{cluster_snapshot.title}" : "Report: Cluster Analysis"
    end
  end
end
