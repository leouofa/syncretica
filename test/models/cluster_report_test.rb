# frozen_string_literal: true

require "test_helper"

class ClusterReportTest < ActiveSupport::TestCase
  setup do
    @snapshot = ClusterSnapshot.create!(
      target_type: "God",
      level: 5,
      distance_threshold: 0.20,
      title: "God Archetypes Test Snapshot",
      clusters_count: 2,
      items_count: 5
    )
  end

  test "validates required fields" do
    report = ClusterReport.new
    assert_not report.valid?
    assert_includes report.errors[:prompt], "can't be blank"

    report.prompt = "Find archetypes"
    report.cluster_snapshot = @snapshot
    assert report.valid?
    assert_equal "Find archetypes", report.title
    assert_equal "pending", report.status
  end

  test "assigns default title if prompt is truncated appropriately" do
    long_prompt = "A" * 120
    report = @snapshot.cluster_reports.create!(prompt: long_prompt)
    assert_operator report.title.length, :<=, 72
  end

  test "status transitions" do
    report = @snapshot.cluster_reports.create!(prompt: "Analyze patterns")
    assert report.pending?
    assert report.in_progress?

    report.mark_running!
    assert report.running?
    assert report.in_progress?

    report.mark_completed!(markdown_content: "# Findings\nGreat patterns.", refined_title: "Findings on Deities")
    assert report.completed?
    assert_not report.in_progress?
    assert_equal "Findings on Deities", report.title
    assert_equal "# Findings\nGreat patterns.", report.content
    assert_not_nil report.completed_at

    report.mark_failed!("LLM timeout")
    assert report.failed?
    assert_equal "LLM timeout", report.error_message
  end

  test "destroyed when parent snapshot is destroyed" do
    report = @snapshot.cluster_reports.create!(prompt: "Analyze")
    assert_difference("ClusterReport.count", -1) do
      @snapshot.destroy
    end
    assert_nil ClusterReport.find_by(id: report.id)
  end

  test "detailed reports track batching and progress" do
    report = @snapshot.cluster_reports.create!(prompt: "Deep dive", is_detailed: true, batch_size: 5)
    assert report.detailed?
    assert_not @snapshot.cluster_reports.create!(prompt: "Standard").detailed?

    report.mark_running!(
      phase: ClusterReport::PHASE_AGGREGATING_BATCHES,
      total_clusters: 10,
      total_batches: 2
    )
    assert_equal 2, report.total_batches_count
    assert_includes report.phase_description, "Aggregating batch 0 of 2"

    report.update!(aggregated_batches_count: 1)
    assert_equal 80, report.progress_percentage
  end

  test "non-detailed reports keep the two-phase progress semantics" do
    report = @snapshot.cluster_reports.create!(prompt: "Standard")
    report.mark_running!(total_clusters: 4)
    report.update!(summarized_clusters_count: 2)
    assert_equal 35, report.progress_percentage
    assert_includes report.phase_description, "Phase 1 of 2"

    report.update!(phase: ClusterReport::PHASE_SYNTHESIZING_REPORT)
    assert_equal 92, report.progress_percentage
    assert_includes report.phase_description, "Phase 2 of 2"
  end

  test "parent and detailed reports associations" do
    parent = @snapshot.cluster_reports.create!(prompt: "Original")
    child = @snapshot.cluster_reports.create!(prompt: "Original", is_detailed: true, parent_report: parent)

    assert_equal parent, child.parent_report
    assert_includes parent.detailed_reports, child

    # If parent is destroyed, child's parent_report_id is nullified
    parent.destroy
    assert_nil child.reload.parent_report_id
  end

  test "copy_summaries_from! clones cluster report summaries and updates count" do
    source = @snapshot.cluster_reports.create!(prompt: "Original")
    group1 = @snapshot.cluster_groups.create!(name: "Group 1", shared_themes: [ "theme1" ], size: 2)
    group2 = @snapshot.cluster_groups.create!(name: "Group 2", shared_themes: [ "theme2" ], size: 3)

    source.cluster_report_summaries.create!(cluster_group: group1, position: 1, content: "Summary 1")
    source.cluster_report_summaries.create!(cluster_group: group2, position: 2, content: "Summary 2")

    target = @snapshot.cluster_reports.create!(prompt: "Original", is_detailed: true, parent_report: source)
    copied_count = target.copy_summaries_from!(source)

    assert_equal 2, copied_count
    assert_equal 2, target.cluster_report_summaries.count
    assert_equal 2, target.summarized_clusters_count

    summaries = target.cluster_report_summaries.ordered.to_a
    assert_equal [ 1, 2 ], summaries.map(&:position)
    assert_equal [ group1.id, group2.id ], summaries.map(&:cluster_group_id)
    assert_equal [ "Summary 1", "Summary 2" ], summaries.map(&:content)
    assert_equal [ target.id, target.id ], summaries.map(&:cluster_report_id)
  end

  test "copy_summaries_from! returns 0 when source is nil or has no summaries" do
    target = @snapshot.cluster_reports.create!(prompt: "Original", is_detailed: true)
    assert_equal 0, target.copy_summaries_from!(nil)

    empty_source = @snapshot.cluster_reports.create!(prompt: "Empty")
    assert_equal 0, target.copy_summaries_from!(empty_source)
  end
end
