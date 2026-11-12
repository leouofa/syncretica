# frozen_string_literal: true

require "test_helper"

class ClusterReportSummaryTest < ActiveSupport::TestCase
  setup do
    @snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 5,
      distance_threshold: 0.20,
      title: "God Archetypes Test Snapshot",
      clusters_count: 1,
      items_count: 2
    )
    @group = @snapshot.cluster_groups.create!(name: "Solar Realm", shared_themes: [ "sun" ], size: 2)
    @report = @snapshot.cluster_reports.create!(prompt: "Find patterns across myths or gods")
  end

  test "validates required fields and uniqueness of cluster group per report" do
    summary = ClusterReportSummary.new
    assert_not summary.valid?

    summary.cluster_report = @report
    summary.cluster_group = @group
    summary.content = "Analysis of the solar domain."
    summary.position = 1
    assert summary.valid?
    summary.save!

    duplicate = ClusterReportSummary.new(
      cluster_report: @report,
      cluster_group: @group,
      content: "Duplicate entry",
      position: 2
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:cluster_group_id], "has already been taken"
  end

  test "cascades deletion when cluster report is destroyed" do
    summary = @report.cluster_report_summaries.create!(
      cluster_group: @group,
      content: "Summary text",
      position: 1
    )

    assert_difference("ClusterReportSummary.count", -1) do
      @report.destroy
    end
    assert_nil ClusterReportSummary.find_by(id: summary.id)
  end
end
