# frozen_string_literal: true

class ClusterReport < ApplicationRecord
  STATUS_PENDING   = "pending"
  STATUS_RUNNING   = "running"
  STATUS_COMPLETED = "completed"
  STATUS_FAILED    = "failed"

  STATUSES = [ STATUS_PENDING, STATUS_RUNNING, STATUS_COMPLETED, STATUS_FAILED ].freeze

  PHASE_QUEUED               = "queued"
  PHASE_SUMMARIZING_CLUSTERS = "summarizing_clusters"
  PHASE_AGGREGATING_BATCHES  = "aggregating_batches"
  PHASE_SYNTHESIZING_REPORT  = "synthesizing_report"
  PHASE_COMPLETED            = "completed"
  PHASE_FAILED               = "failed"

  PHASES = [
    PHASE_QUEUED,
    PHASE_SUMMARIZING_CLUSTERS,
    PHASE_AGGREGATING_BATCHES,
    PHASE_SYNTHESIZING_REPORT,
    PHASE_COMPLETED,
    PHASE_FAILED
  ].freeze

  DEFAULT_BATCH_SIZE = 5
  BATCH_SIZE_RANGE = (2..50).freeze

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
  has_many :cluster_sub_reports, dependent: :destroy

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

  def detailed?
    is_detailed?
  end

  def mark_running!(phase: PHASE_SUMMARIZING_CLUSTERS, total_clusters: nil, total_batches: nil)
    attrs = { status: STATUS_RUNNING, phase: phase }
    attrs[:total_clusters_count] = total_clusters if total_clusters.present?
    attrs[:total_batches_count] = total_batches if total_batches.present?
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
      # 0% - 70% allocated to summarizing clusters
      ((summarized_clusters_count.to_f / total_clusters_count) * 70).round
    when PHASE_AGGREGATING_BATCHES
      # 70% - 90% allocated to aggregating batch analyses
      return 70 if total_batches_count.zero?

      70 + ((aggregated_batches_count.to_f / total_batches_count) * 20).round
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
      if detailed?
        "Phase 1 of 3: Analyzing cluster #{summarized_clusters_count} of #{total_clusters_count} through inquiry lens..."
      else
        "Phase 1 of 2: Analyzing cluster #{summarized_clusters_count} of #{total_clusters_count} through inquiry lens..."
      end
    when PHASE_AGGREGATING_BATCHES
      "Phase 2 of 3: Aggregating batch #{aggregated_batches_count} of #{total_batches_count} into mid-level analyses..."
    when PHASE_SYNTHESIZING_REPORT
      if detailed?
        "Phase 3 of 3: Synthesizing deep report from #{total_batches_count} batch analyses..."
      else
        "Phase 2 of 2: Synthesizing final comparative report from #{total_clusters_count} cluster analyses..."
      end
    when PHASE_COMPLETED
      "Report generation complete"
    when PHASE_FAILED
      "Generation failed"
    else
      status.titleize
    end
  end

  def progress_label
    case phase
    when PHASE_SUMMARIZING_CLUSTERS then "Summarizing Clusters..."
    when PHASE_AGGREGATING_BATCHES then "Aggregating Batches..."
    when PHASE_SYNTHESIZING_REPORT then "Synthesizing Report..."
    else "Processing..."
    end
  end

  def progress_message
    case phase
    when PHASE_SUMMARIZING_CLUSTERS
      "Each cluster's full members are being analyzed through your inquiry lens before synthesis."
    when PHASE_AGGREGATING_BATCHES
      "Cluster analyses are being aggregated into mid-level batch narratives."
    when PHASE_SYNTHESIZING_REPORT
      detailed? ? "Synthesizing the batch analyses into a detailed deep report..." : "Synthesizing cross-cluster archetypes into the final report..."
    else
      "Processing..."
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
