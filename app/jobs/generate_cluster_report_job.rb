# frozen_string_literal: true

class GenerateClusterReportJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 0

  def perform(cluster_report_id)
    report = ClusterReport.find_by(id: cluster_report_id)
    return unless report
    return if report.completed?

    Llm::ModelRegistry.ensure_configured_model!

    snapshot = report.cluster_snapshot
    groups = snapshot.cluster_groups.by_size.includes(cluster_memberships: eager_associations(snapshot.target_type)).to_a

    existing_summaries_count = report.cluster_report_summaries.count
    initial_phase = if existing_summaries_count >= groups.size
      report.detailed? ? ClusterReport::PHASE_AGGREGATING_BATCHES : ClusterReport::PHASE_SYNTHESIZING_REPORT
    else
      ClusterReport::PHASE_SUMMARIZING_CLUSTERS
    end

    report.mark_running!(
      phase: initial_phase,
      total_clusters: groups.size,
      total_batches: total_batches_for(report, groups)
    )
    report.update!(summarized_clusters_count: existing_summaries_count) if report.summarized_clusters_count != existing_summaries_count
    broadcast_report_update(report)

    # Phase 1: Map - Prompt-guided summarization for each cluster group
    summarize_clusters(report, snapshot, groups) if existing_summaries_count < groups.size

    if report.detailed?
      # Phase 2: Aggregation - Batch the cluster summaries into mid-level analyses
      aggregate_batches(report)

      # Phase 3: Deep synthesis - Final detailed report from all batch analyses
      synthesize_deep_report(report, snapshot)
    else
      # Phase 2: Reduce - Final report synthesis across all cluster analyses
      synthesize_report(report, snapshot)
    end
  rescue StandardError => e
    Rails.logger.error("[GenerateClusterReportJob] Report=#{cluster_report_id} #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    report&.mark_failed!(e.message)
    broadcast_report_update(report) if report
  end

  private

  def summarize_clusters(report, snapshot, groups)
    groups.each_with_index do |group, index|
      # Skip if summary already generated
      next if report.cluster_report_summaries.exists?(cluster_group_id: group.id)

      group_detail = Clustering::SnapshotDigestBuilder.format_full_group_detail(
        group,
        target_type: snapshot.target_type
      )

      chat = ClusterGroupSummaryAgent.create!(
        report_prompt: report.prompt,
        snapshot_title: snapshot.title,
        target_type: snapshot.target_type,
        cluster_rank: index + 1,
        total_clusters: groups.size,
        cluster_name: group.name,
        cluster_size: group.size,
        shared_themes: group.shared_themes,
        cluster_members_detail: group_detail
      )

      cluster_inquiry = "Synthesize this cluster's mythological archetype patterns and motifs specifically answering: #{report.prompt}"
      response = chat.ask(cluster_inquiry)

      cleaned_summary = clean_markdown(response.content)

      report.cluster_report_summaries.create!(
        cluster_group: group,
        chat: chat.is_a?(Chat) ? chat : nil,
        position: index + 1,
        content: cleaned_summary
      )

      report.update!(summarized_clusters_count: report.cluster_report_summaries.count)
      broadcast_report_update(report)
    end
  end

  def aggregate_batches(report)
    report.update!(phase: ClusterReport::PHASE_AGGREGATING_BATCHES)
    broadcast_report_update(report)

    batch_size = report.batch_size.to_i
    batch_size = 1 if batch_size < 1

    summaries = report.cluster_report_summaries.ordered.to_a
    slices = summaries.each_slice(batch_size).to_a
    total = slices.size

    slices.each_with_index do |batch_summaries, index|
      batch_index = index + 1

      # Resume support: skip batches already persisted
      next if report.cluster_sub_reports.exists?(batch_index: batch_index)

      digest = Clustering::SubReportDigestBuilder.batch_digest(
        report,
        batch_summaries,
        batch_index: batch_index,
        total_batches: total
      )

      chat = ClusterBatchSummaryAgent.create!(
        report_prompt: report.prompt,
        snapshot_title: report.cluster_snapshot.title,
        target_type: report.cluster_snapshot.target_type,
        batch_index: batch_index,
        total_batches: total,
        cluster_count: batch_summaries.size,
        batch_digest: digest
      )

      batch_inquiry = "Aggregate these #{batch_summaries.size} cluster analyses into a coherent mid-level narrative for the deep report."
      response = chat.ask(batch_inquiry)

      report.cluster_sub_reports.create!(
        batch_index: batch_index,
        cluster_group_ids: batch_summaries.map(&:cluster_group_id),
        chat: chat.is_a?(Chat) ? chat : nil,
        content: clean_markdown(response.content)
      )

      report.update!(aggregated_batches_count: report.cluster_sub_reports.count)
      broadcast_report_update(report)
    end
  end

  def synthesize_deep_report(report, snapshot)
    report.update!(phase: ClusterReport::PHASE_SYNTHESIZING_REPORT)
    broadcast_report_update(report)

    sub_reports = report.cluster_sub_reports.ordered.to_a
    digest = Clustering::SubReportDigestBuilder.synthesis_digest(report, sub_reports)

    chat = DeepSynthesisReportAgent.create!(
      snapshot_title: snapshot.title,
      target_type: snapshot.target_type,
      level: snapshot.level,
      distance_threshold: snapshot.distance_threshold,
      clusters_count: snapshot.clusters_count,
      items_count: snapshot.items_count,
      sub_report_digest: digest
    )

    report.update!(chat: chat) if chat.is_a?(Chat)

    prompt = report.prompt.presence || ClusterReport::DEFAULT_PROMPT
    response = chat.ask(prompt)

    cleaned_content = clean_markdown(response.content)
    refined_title = extract_title(cleaned_content)

    report.mark_completed!(
      markdown_content: cleaned_content,
      refined_title: refined_title
    )
    broadcast_report_update(report)
  end

  def total_batches_for(report, groups)
    return 0 unless report.detailed?

    batch_size = report.batch_size.to_i
    batch_size = ClusterReport::DEFAULT_BATCH_SIZE if batch_size < 1
    [ (groups.size.to_f / batch_size).ceil, 1 ].max
  end

  def synthesize_report(report, snapshot)
    report.update!(phase: ClusterReport::PHASE_SYNTHESIZING_REPORT)
    broadcast_report_update(report)

    digest = Clustering::SnapshotDigestBuilder.call(snapshot, report: report)

    chat = ClusterReportAgent.create!(
      snapshot_title: snapshot.title,
      target_type: snapshot.target_type,
      level: snapshot.level,
      distance_threshold: snapshot.distance_threshold,
      clusters_count: snapshot.clusters_count,
      items_count: snapshot.items_count,
      snapshot_digest: digest
    )

    report.update!(chat: chat) if chat.is_a?(Chat)

    prompt = report.prompt.presence || ClusterReport::DEFAULT_PROMPT
    response = chat.ask(prompt)

    cleaned_content = clean_markdown(response.content)
    refined_title = extract_title(cleaned_content)

    report.mark_completed!(
      markdown_content: cleaned_content,
      refined_title: refined_title
    )
    broadcast_report_update(report)
  end

  def eager_associations(target_type)
    case target_type
    when "God"
      { record: :pantheon }
    when "Myth"
      { record: { god: :pantheon } }
    else
      :record
    end
  end

  def clean_markdown(raw)
    text = raw.to_s.strip
    # Strip <think> reasoning tags
    text = text.gsub(%r{<think>.*?</think>}m, "").strip

    # Strip outer markdown fences if the whole response was wrapped in ```markdown ... ```
    if text.start_with?("```markdown") && text.end_with?("```")
      text = text.sub(/\A```markdown\s*/, "").sub(/\s*```\z/, "").strip
    elsif text.start_with?("```") && text.end_with?("```")
      text = text.sub(/\A```\w*\s*/, "").sub(/\s*```\z/, "").strip
    end

    text
  end

  def extract_title(content)
    first_h1 = content.lines.find { |line| line.strip.start_with?("# ") }
    return nil unless first_h1

    first_h1.sub(/\A#\s+/, "").strip.truncate(90)
  end

  def broadcast_report_update(report)
    snapshot = report.cluster_snapshot

    # Broadcast to snapshot show page stream
    Turbo::StreamsChannel.broadcast_replace_to(
      "cluster_snapshot_#{snapshot.id}_reports",
      target: "cluster_report_#{report.id}",
      partial: "cluster_reports/report_card",
      locals: { report: report, snapshot: snapshot }
    )

    # Broadcast to report show page stream
    Turbo::StreamsChannel.broadcast_replace_to(
      "cluster_report_#{report.id}",
      target: "cluster_report_detail_#{report.id}",
      partial: "cluster_reports/report_detail",
      locals: { report: report }
    )

    # Also update snapshot-level reports count / header if needed
    Turbo::StreamsChannel.broadcast_replace_to(
      "cluster_snapshot_#{snapshot.id}_reports",
      target: "snapshot_reports_count",
      partial: "cluster_reports/reports_count",
      locals: { count: snapshot.cluster_reports.count }
    )
  end
end
