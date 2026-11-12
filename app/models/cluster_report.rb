# frozen_string_literal: true

class ClusterReport < ApplicationRecord
  STATUS_PENDING   = "pending"
  STATUS_RUNNING   = "running"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED    = "failed"

  STATUSES = [ STATUS_PENDING, STATUS_RUNNING, STATUS_COMPLETED, STATUS_FAILED ].freeze

  PHASE_QUEUED               = "queued"
  PHASE_SUMMARIZING_CLUSTERS = "summarizing_clusters"
  PHASE_SYNTHESIZING_REPORT  = "synthesizing_report"
  PHASE_COMPLETED            = "completed"
  PHASE_FAILED               = "failed"

  PHASES = [
    PHASE_QUEUED,
    PHASE_SUMMARIZING_CLUSTERS,
    PHASE_SYNTHESIZING_REPORT,
    PHASE_COMPLETED,
    PHASE_FAILED
  ].freeze

  DEFAULT_PROMPT = "Find interesting patterns across myths or gods, highlighting cross-pantheon archetypes, structural motifs, and surprising connections."

  PRESET_PROMPTS = [
    "Find interesting patterns across myths or gods",
    "Identify cross-pantheon archetypes and functional equivalents",
    "Spot unexpected connections, overlaps, and thematic outliers",
    "Analyze the balance of creation, order, trickery, and destruction motifs"
  ].freeze

  belongs_to :cluster_snapshot
  belongs_to :chat, optional: true
  has_many :cluster_report_summaries, dependent: :destroy

  validates :title, presence: true
  validates :prompt, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :phase, presence: true, inclusion: { in: PHASES }

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

  def mark_running!(phase: PHASE_SUMMARIZING_CLUSTERS, total_clusters: nil)
    attrs = { status: STATUS_RUNNING, phase: phase }
    attrs[:total_clusters_count] = total_clusters if total_clusters.present?
    update!(attrs)
  end

  def mark_completed!(markdown_content:, refined_title: nil)
    attrs = {
      status: STATUS_COMPLETED,
      phase: PHASE_COMPLETED,
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
      phase: PHASE_FAILED,
      error_message: message.to_s.truncate(1000)
    )
  end

  def progress_percentage
    return 100 if completed?
    return 0 if total_clusters_count.zero?

    case phase
    when PHASE_SUMMARIZING_CLUSTERS
      # 0% - 85% allocated to summarizing clusters
      ((summarized_clusters_count.to_f / total_clusters_count) * 85).round
    when PHASE_SYNTHESIZING_REPORT
      92
    else
      0
    end
  end

  def phase_description
    case phase
    when PHASE_QUEUED
      "Queued for processing"
    when PHASE_SUMMARIZING_CLUSTERS
      "Phase 1 of 2: Analyzing cluster #{summarized_clusters_count} of #{total_clusters_count} through inquiry lens..."
    when PHASE_SYNTHESIZING_REPORT
      "Phase 2 of 2: Synthesizing final comparative report from #{total_clusters_count} cluster analyses..."
    when PHASE_COMPLETED
      "Report generation complete"
    when PHASE_FAILED
      "Generation failed"
    else
      status.titleize
    end
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
