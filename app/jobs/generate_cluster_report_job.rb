# frozen_string_literal: true

class GenerateClusterReportJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 0

  def perform(cluster_report_id)
    report = ClusterReport.find_by(id: cluster_report_id)
    return unless report
    return if report.completed?

    report.mark_running!
    broadcast_report_update(report)

    Llm::ModelRegistry.ensure_configured_model!

    snapshot = report.cluster_snapshot
    digest = Clustering::SnapshotDigestBuilder.call(snapshot)

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
  rescue StandardError => e
    Rails.logger.error("[GenerateClusterReportJob] Report=#{cluster_report_id} #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    report&.mark_failed!(e.message)
    broadcast_report_update(report) if report
  end

  private

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
