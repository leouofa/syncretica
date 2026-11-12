# frozen_string_literal: true

module Clustering
  # Assembles the aggregation-layer inputs and the final deep-synthesis digest
  # for hierarchical (detailed) cluster reports.
  class SubReportDigestBuilder
    # Text block fed to ClusterBatchSummaryAgent for a single batch of clusters.
    def self.batch_digest(report, summaries, batch_index:, total_batches:)
      snapshot = report.cluster_snapshot

      header = <<~HEADER
        === BATCH #{batch_index} OF #{total_batches} ===
        Snapshot: #{snapshot.title} (Target: #{snapshot.target_type})
        Clusters in this batch: #{summaries.size}
        ================================
      HEADER

      blocks = summaries.map do |summary|
        group = summary.cluster_group
        themes = group.shared_themes.presence ? group.shared_themes.join(", ") : "None specified"
        <<~BLOCK.strip
          --- Cluster ##{summary.position}: "#{group.name}" (#{group.size} members) ---
          Shared Themes: #{themes}
          Cluster Analysis:
          #{summary.content.to_s.strip}
        BLOCK
      end

      ([ header.strip ] + blocks).join("\n\n")
    end

    # Token-budget-aware digest fed to DeepSynthesisReportAgent, built from all
    # persisted ClusterSubReport batch analyses plus a snapshot overview header.
    def self.synthesis_digest(report, sub_reports, max_chars: nil)
      budget = max_chars || Llm::ModelRegistry.digest_char_budget
      new(report, sub_reports, max_chars: budget).synthesis_digest
    end

    def initialize(report, sub_reports, max_chars:)
      @report = report
      @snapshot = report.cluster_snapshot
      @sub_reports = sub_reports
      @max_chars = max_chars
    end

    def synthesis_digest
      header = <<~HEADER
        === CLUSTER SNAPSHOT OVERVIEW ===
        Title: #{@snapshot.title}
        Target Type: #{@snapshot.target_type}
        Clustering Level: #{@snapshot.level} (distance threshold <= #{@snapshot.distance_threshold})
        Total Clusters: #{@snapshot.clusters_count}
        Total Persisted Items: #{@snapshot.items_count}
        Aggregation Batches: #{@sub_reports.size}
        Generated At: #{@snapshot.created_at.strftime('%Y-%m-%d %H:%M UTC')}
        =================================

        BATCH-LEVEL ANALYSES (#{@sub_reports.size} total):
      HEADER

      blocks = @sub_reports.map do |sub_report|
        covered = Array(sub_report.cluster_group_ids)
        covered_label = covered.any? ? "covers #{covered.size} clusters: ##{covered.join(', #')}" : "batch #{sub_report.batch_index}"
        <<~BLOCK.strip
          ### Batch ##{sub_report.batch_index} (#{covered_label})
          #{sub_report.content.to_s.strip}
        BLOCK
      end

      full_digest = ([ header.strip ] + blocks).join("\n\n")
      if full_digest.length > @max_chars
        full_digest.truncate(@max_chars, omission: "\n\n... [Aggregation digest truncated to fit context budget] ...")
      else
        full_digest
      end
    end
  end
end
